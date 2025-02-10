
#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/rtio/rtio.h>
#include <zephyr/rtio/work.h>

#if CONFIG_TOSHIBA_TCD1304_PWM
#include <zephyr/drivers/pwm.h>
#endif

#define DT_DRV_COMPAT toshiba_tcd1304

LOG_MODULE_REGISTER(DT_DRV_COMPAT);

#define TCD1304_MIN_FREQ_HZ (800000)
#define TCD1304_MAX_FREQ_HZ (4000000)

#define TCD1304_NUM_DUMMY_LEFT  (32)
#define TCD1304_NUM_ELEMENTS    (3648)
#define TCD1304_NUM_DUMMY_RIGHT (14)
#define TCD1304_NUM_ELEMENTS_TOTAL                                             \
        (TCD1304_NUM_DUMMY_LEFT + TCD1304_NUM_DUMMY_RIGHT +                    \
         TCD1304_NUM_ELEMENTS)

#define TCD1304_FIFO_WMARK_FAKE (256)

struct tcd1304_cfg {
        const struct gpio_dt_spec gpio_icg;
        const struct gpio_dt_spec gpio_sh;

        const struct adc_dt_spec adc;
        uint32_t dt_sample_rate;

#if CONFIG_TOSHIBA_TCD1304_PWM
        const struct pwm_dt_spec pwm_master;
#endif
};

struct tcd1304_data {
        struct adc_sequence_options adc_options;
        struct adc_sequence adc_seq;
        struct k_poll_signal adc_done;

        uint32_t clock_frequency;

        struct rtio_iodev_sqe *iodev_sqe;
        struct rtio *rtio_ctx;

        uint8_t *buf;
        size_t buf_size;

        struct k_work_poll work_done;
        struct k_poll_event work_event;

        /* Reference to self to obtain the device from the data struct */
        const struct device *dev;
};

static inline uint32_t tcd1304_clock_period_ns(uint32_t freq)
{
        return (uint32_t)(((uint32_t)1e9) / freq);
}

static int tcd1304_clocks_start(const struct device *dev)
{
#if CONFIG_TOSHIBA_TCD1304_PWM
        int status;
        uint32_t period;
        struct tcd1304_data *data;
        const struct tcd1304_cfg *cfg;

        data = dev->data;
        cfg = dev->config;

        period = tcd1304_clock_period_ns(data->clock_frequency);
        status = pwm_set_dt(&cfg->pwm_master, period, period / 2);
        if (status != 0) {
                return status;
        }

        return 0;
#else
        ARG_UNUSED(dev);
        return 0;
#endif
}

static int tcd1304_clocks_stop(const struct device *dev)
{
#if CONFIG_TOSHIBA_TCD1304_PWM
        int status;
        const struct tcd1304_cfg *cfg;

        cfg = dev->config;

        status = pwm_set_dt(&cfg->pwm_master, 0, 0);
        if (status != 0) {
                return status;
        }

        return 0;
#else
        ARG_UNUSED(dev);
        return 0;
#endif
}

/** @brief Start reading out from the detector.
 *
 * This begins periodcally reading out samples from the ADC, invoking
 * the ADC callback function. That repeats sampling for each pixel in the
 * CCD, before completing.
 *
 * @param dev
 * @return int Status code
 * @retval 0 Success
 * @retval <0 Errno code
 */
static int tcd1304_start_read(const struct device *dev)
{
        int status;
        const struct tcd1304_cfg *cfg = dev->config;
        struct tcd1304_data *data = dev->data;

        data->adc_seq.buffer = data->buf;
        data->adc_seq.buffer_size = data->buf_size;

        status = tcd1304_clocks_start(dev);
        if (status != 0) {
                return status;
        }

        /* TODO: Determine integration time requirement */
        status = gpio_pin_set_dt(&cfg->gpio_sh, 1);
        if (status != 0) {
                return status;
        }

        status = gpio_pin_set_dt(&cfg->gpio_icg, 1);
        if (status != 0) {
                return status;
        }

        status = adc_read_async(cfg->adc.dev, &data->adc_seq, &data->adc_done);
        if (status != 0) {
                return status;
        }

        return 0;
}

static void tcd1304_stop_read(const struct device *dev)
{
        const struct tcd1304_cfg *cfg = dev->config;

        (void)gpio_pin_set_dt(&cfg->gpio_icg, 0);
        (void)gpio_pin_set_dt(&cfg->gpio_sh, 0);
        (void)tcd1304_clocks_stop(dev);
}

static void tcd1304_done(struct k_work *work)
{
        struct k_work_poll *poll_work =
                CONTAINER_OF(work, struct k_work_poll, work);
        struct tcd1304_data *data =
                CONTAINER_OF(poll_work, struct tcd1304_data, work_done);
        unsigned int signaled;
        int result;
        struct rtio_iodev_sqe *iodev_sqe;

        iodev_sqe = data->iodev_sqe;
        data->iodev_sqe = NULL;
        data->buf = NULL;

        tcd1304_stop_read(data->dev);

        k_poll_signal_check(&data->adc_done, &signaled, &result);
        k_poll_signal_reset(&data->adc_done);

        if (!signaled) {
                LOG_ERR("timed out");
                rtio_iodev_sqe_err(iodev_sqe, -ETIMEDOUT);
        } else {
                rtio_iodev_sqe_ok(iodev_sqe, 0);
        }
}

static void tcd1304_submit_sync(struct rtio_iodev_sqe *iodev_sqe)
{
        int status;
        const struct sensor_read_config *cfg = iodev_sqe->sqe.iodev->data;
        const struct device *dev = cfg->sensor;
        struct tcd1304_data *data = dev->data;
        size_t req_size;

        if (cfg->is_streaming) {
                LOG_ERR("streaming mode is not supported");
                rtio_iodev_sqe_err(iodev_sqe, -EINVAL);
                return;
        }

        req_size = TCD1304_NUM_ELEMENTS_TOTAL * sizeof(uint16_t);
        status = rtio_sqe_rx_buf(iodev_sqe, req_size, req_size, &data->buf,
                                 &data->buf_size);
        if (status != 0) {
                LOG_ERR("failed to get rx buf: %i", status);
                rtio_iodev_sqe_err(iodev_sqe, status);
        }

        data->iodev_sqe = iodev_sqe;

        status = k_work_poll_submit(&data->work_done, &data->work_event, 1,
                                    K_MSEC(10));
        if (status != 0) {
                LOG_ERR("unable to submit to queue: %i", status);
                rtio_iodev_sqe_err(iodev_sqe, status);
                return;
        }

        status = tcd1304_start_read(dev);
        if (status != 0) {
                LOG_ERR("unable to start read: %i", status);
                rtio_iodev_sqe_err(iodev_sqe, status);
        }
}

static void tcd1304_submit(const struct device *sensor,
                           struct rtio_iodev_sqe *iodev_sqe)
{
        struct rtio_work_req *req = rtio_work_req_alloc();
        if (req == NULL) {
                LOG_ERR("RTIO work req allocation failed");
                return;
        }

        rtio_work_req_submit(req, iodev_sqe, tcd1304_submit_sync);
}

static int tcd1304_set_sample_rate(const struct device *dev, int32_t rate_hz)
{
        struct tcd1304_data *data = dev->data;
        uint32_t freq = rate_hz * 4;

        if (freq > TCD1304_MAX_FREQ_HZ || freq < TCD1304_MIN_FREQ_HZ) {
                return -EINVAL;
        }

        data->clock_frequency = freq;
        data->adc_options.interval_us = tcd1304_clock_period_ns(rate_hz);

        return 0;
}

static int32_t tcd1304_get_sample_rate(const struct device *dev)
{
        struct tcd1304_data *data = dev->data;

        return data->clock_frequency / 4;
}

static int tcd1304_attr_set(const struct device *dev, enum sensor_channel chan,
                            enum sensor_attribute attr,
                            const struct sensor_value *val)
{
        switch (attr) {
        case SENSOR_ATTR_SAMPLING_FREQUENCY:
                return tcd1304_set_sample_rate(dev, val->val1);
        default:
                break;
        }

        return -EINVAL;
}

static int tcd1304_attr_get(const struct device *dev, enum sensor_channel chan,
                            enum sensor_attribute attr,
                            struct sensor_value *val)
{
        switch (attr) {
        case SENSOR_ATTR_SAMPLING_FREQUENCY:
                val->val1 = tcd1304_get_sample_rate(dev);
                return 0;
        default:
                break;
        }

        return -EINVAL;
}

static int tcd1304_init(const struct device *dev)
{
        int status;
        const struct tcd1304_cfg *cfg;
        struct tcd1304_data *data;

        cfg = dev->config;
        data = dev->data;

        if (!adc_is_ready_dt(&cfg->adc)) {
                LOG_ERR("adc not ready");
                return -EBUSY;
        }

#if CONFIG_TOSHIBA_TCD1304_PWM
        if (!device_is_ready(cfg->pwm_master.dev)) {
                LOG_ERR("pwm not ready");
                return -EBUSY;
        }
#endif

        if (!gpio_is_ready_dt(&cfg->gpio_icg) ||
            !gpio_is_ready_dt(&cfg->gpio_sh)) {
                LOG_ERR("gpio not ready");
                return -EBUSY;
        }

        data->adc_seq.channels = 1;
        data->adc_seq.oversampling = 0;
        data->adc_seq.resolution = 16;
        data->adc_seq.calibrate = 0;
        data->adc_seq.options = &data->adc_options;
        data->adc_options.user_data = (void *)dev;
        data->adc_options.callback = NULL;
        data->adc_options.extra_samplings = TCD1304_NUM_ELEMENTS_TOTAL - 1;

        k_poll_signal_init(&data->adc_done);
        k_work_poll_init(&data->work_done, tcd1304_done);

        k_poll_event_init(&data->work_event, K_POLL_TYPE_SIGNAL,
                          K_POLL_MODE_NOTIFY_ONLY, &data->adc_done);

        status = tcd1304_set_sample_rate(dev, cfg->dt_sample_rate);
        if (status != 0) {
                return status;
        }

        status = gpio_pin_configure_dt(&cfg->gpio_icg, GPIO_OUTPUT);
        if (status != 0) {
                return status;
        }

        status = gpio_pin_configure_dt(&cfg->gpio_sh, GPIO_OUTPUT);
        if (status != 0) {
                return status;
        }

        return 0;
}

extern int tcd1304_get_decoder(const struct device *dev,
                               const struct sensor_decoder_api **api);

static DEVICE_API(sensor, tcd1304_api) = {
        .attr_set = tcd1304_attr_set,
        .attr_get = tcd1304_attr_get,
        .submit = tcd1304_submit,
        .get_decoder = tcd1304_get_decoder,
};

#if CONFIG_TOSHIBA_TCD1304_PWM
#define TCD1304_CLOCK_CFG(node)                                                \
        .pwm_master = PWM_DT_SPEC_INST_GET_BY_NAME(node, clock)
#else
#define TCD1304_CLOCK_CFG(node)
#endif

#define TCD1304_INIT(node)                                                     \
        static const struct tcd1304_cfg tcd1304_cfg_##node##__ = {             \
                .gpio_icg = GPIO_DT_SPEC_INST_GET_BY_IDX(node, gpios, 0),      \
                .gpio_sh = GPIO_DT_SPEC_INST_GET_BY_IDX(node, gpios, 1),       \
                .adc = ADC_DT_SPEC_INST_GET(node),                             \
                .dt_sample_rate = DT_INST_PROP_OR(node, sampling_rate, 0),     \
                TCD1304_CLOCK_CFG(node),                                       \
        };                                                                     \
        static struct tcd1304_data tcd1304_data_##node##__;                    \
        DEVICE_DT_INST_DEFINE(node, tcd1304_init, NULL,                        \
                              &tcd1304_data_##node##__,                        \
                              &tcd1304_cfg_##node##__, POST_KERNEL,            \
                              CONFIG_SENSOR_INIT_PRIORITY, NULL);

DT_INST_FOREACH_STATUS_OKAY(TCD1304_INIT);
