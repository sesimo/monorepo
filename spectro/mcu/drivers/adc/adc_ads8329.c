
#include <zephyr/device.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/drivers/pwm.h>
#include <zephyr/logging/log.h>

/* Found in ${ZEPHYR_BASE}/drivers/adc */
#include <adc_context.h>

#define DT_DRV_COMPAT ti_ads8329

LOG_MODULE_REGISTER(DT_DRV_COMPAT);

#define ADS8329_REG_CFR_READ  (0xc)
#define ADS8329_REG_DATA      (0xd)
#define ADS8329_REG_CFR_WRITE (0xe)

#define ADS8329_CFR_CHAN_AUTO        (1 << 11)
#define ADS8329_CFR_CLK_INTRN        (1 << 10)
#define ADS8329_CFR_TRIG_MANUAL      (1 << 9)
/* D8 reserved */
#define ADS8329_CFR_EOC_ACTIVE_LOW   (1 << 7)
#define ADS8329_CFR_EOC_ENABLED      (1 << 6)
#define ADS8329_CFR_EOC_OUTPUT       (1 << 5)
#define ADS8329_CFR_NAP_AUTO_DISABLE (1 << 4)
#define ADS8329_CFR_NAP_WAKE         (1 << 3)
#define ADS8329_CFR_DEEP_SLEEP_WAKE  (1 << 2)
/* D1 ignored on ADS8329 */
#define ADS8329_CFR_NO_RESET         (1 << 0)

/* Default CFR value. This value is specified in the datasheet */
#define ADS8329_CFR_DEFAULT                                                    \
        (ADS8329_CFR_CHAN_AUTO | ADS8329_CFR_CLK_INTRN |                       \
         ADS8329_CFR_TRIG_MANUAL | ADS8329_CFR_EOC_ACTIVE_LOW |                \
         ADS8329_CFR_EOC_ENABLED | ADS8329_CFR_EOC_OUTPUT |                    \
         ADS8329_CFR_NAP_AUTO_DISABLE | ADS8329_CFR_NAP_WAKE |                 \
         ADS8329_CFR_DEEP_SLEEP_WAKE)

#define ADS8329_RESOLUTION (16)

/* Requires a minimum of 40ns */
#define ADS8329_STCONV_HOLD_TIME_NS (100)

struct ads8329_cfg {
        const struct spi_dt_spec spi;
        struct pwm_dt_spec pwm_trigger;
        struct gpio_dt_spec ready_gpio;
};

struct ads8329_data {
        struct adc_context ctx;
        struct gpio_callback ready_cb;

        struct k_sem sig;

        uint16_t *buffer;
        uint16_t *repeat_buffer;

        /* Reference to self, so that it can be accessed through both
         * ctx and ready_cb */
        const struct device *dev;

        struct k_thread aq_thread;
        K_KERNEL_STACK_MEMBER(aq_stack, CONFIG_ADC_ADS8329_THREAD_STACK_SIZE);
};

static int ads8329_write_reg(const struct device *dev, unsigned int reg,
                             uint16_t value)
{
        uint8_t buf[2];
        const struct ads8329_cfg *cfg = dev->config;
        struct spi_buf tx_buf = {
                .buf = buf,
                .len = 2,
        };
        struct spi_buf_set tx = {
                .buffers = &tx_buf,
                .count = 1,
        };

        buf[0] = ((reg & 0xf) << 4) | ((value >> 8) & 0xf);
        buf[1] = (value & 0xff);

        return spi_write_dt(&cfg->spi, &tx);
}

static int ads8329_read_reg(const struct device *dev, unsigned int reg,
                            uint16_t *value)
{
        int status;
        const struct ads8329_cfg *cfg = dev->config;
        uint8_t tx_mem[2];
        uint8_t rx_mem[ARRAY_SIZE(tx_mem)];
        struct spi_buf tx_buf = {
                .buf = tx_mem,
                .len = ARRAY_SIZE(tx_mem),
        };
        struct spi_buf rx_buf = {
                .buf = rx_mem,
                .len = ARRAY_SIZE(rx_mem),
        };
        struct spi_buf_set tx = {
                .buffers = &tx_buf,
                .count = 1,
        };
        struct spi_buf_set rx = {
                .buffers = &rx_buf,
                .count = 1,
        };

        tx_mem[0] = (reg & 0xf) << 4;
        tx_mem[1] = 0;

        status = spi_transceive_dt(&cfg->spi, &tx, &rx);
        if (status != 0) {
                return status;
        }

        *value = (rx_mem[0] << 8) | rx_mem[1];

        return 0;
}

static int ads8329_read_cfr(const struct device *dev, uint16_t *cfr)
{
        return ads8329_read_reg(dev, ADS8329_REG_CFR_READ, cfr);
}

static int ads8329_write_cfr(const struct device *dev, uint16_t cfr)
{
        return ads8329_write_reg(dev, ADS8329_REG_CFR_WRITE, cfr);
}

static int ads8329_reset(const struct device *dev)
{
        uint16_t cfr;
        int status;

        status = ads8329_read_cfr(dev, &cfr);
        if (status != 0) {
                return status;
        }

        cfr &= ~ADS8329_CFR_NO_RESET;

        return ads8329_write_cfr(dev, cfr);
}

static void adc_context_start_sampling(struct adc_context *ctx)
{
        struct ads8329_data *data = CONTAINER_OF(ctx, struct ads8329_data, ctx);

        data->repeat_buffer = data->buffer;
        k_sem_give(&data->sig);
}

static void adc_context_update_buffer_pointer(struct adc_context *ctx,
                                              bool repeat_sampling)
{
        struct ads8329_data *data = CONTAINER_OF(ctx, struct ads8329_data, ctx);

        if (repeat_sampling) {
                data->buffer = data->repeat_buffer;
        }
}

static void adc_context_enable_timer(struct adc_context *ctx)
{
        int status;
        uint32_t period_ns;
        struct ads8329_data *data;
        const struct device *dev;
        const struct ads8329_cfg *cfg;

        data = CONTAINER_OF(ctx, struct ads8329_data, ctx);
        dev = data->dev;
        cfg = dev->config;

        status = gpio_pin_interrupt_configure_dt(&cfg->ready_gpio,
                                                 GPIO_INT_EDGE_TO_ACTIVE);
        if (status != 0) {
                adc_context_complete(ctx, status);
                return;
        }

        period_ns = ctx->sequence.options->interval_us * 1000;
        status = pwm_set_dt(&cfg->pwm_trigger, period_ns,
                            ADS8329_STCONV_HOLD_TIME_NS);
        if (status != 0) {
                adc_context_complete(ctx, status);
                return;
        }
}

static void adc_context_disable_timer(struct adc_context *ctx)
{
        int status;
        struct ads8329_data *data;
        const struct device *dev;
        const struct ads8329_cfg *cfg;

        data = CONTAINER_OF(ctx, struct ads8329_data, ctx);
        dev = data->dev;
        cfg = dev->config;

        status = pwm_set_dt(&cfg->pwm_trigger, 0, 0);
        if (status != 0) {
                LOG_ERR("pwm disable: %i", status);
        }

        status = gpio_pin_interrupt_configure_dt(&cfg->ready_gpio,
                                                 GPIO_INT_MODE_DISABLE_ONLY);
        if (status != 0) {
                LOG_ERR("gpio disable: %i", status);
        }
}

static int ads8329_channel_setup(const struct device *dev,
                                 const struct adc_channel_cfg *channel_cfg)
{
        ARG_UNUSED(dev);

        if (channel_cfg->acquisition_time != ADC_ACQ_TIME_DEFAULT) {
                LOG_ERR("acquisition time config unsupported");
                return -EINVAL;
        }

        if (channel_cfg->gain != ADC_GAIN_1) {
                LOG_ERR("gain config unsupported");
                return -EINVAL;
        }

        if (channel_cfg->reference != ADC_REF_VDD_1) {
                LOG_ERR("reference config unsupported");
                return -EINVAL;
        }

        if (channel_cfg->differential) {
                LOG_ERR("only single-ended is supported");
                return -EINVAL;
        }

        return 0;
}

static int ads8329_validate_seq(const struct adc_sequence *seq)
{
        const struct adc_sequence_options *opts = seq->options;
        size_t needed_bytes;

        if (seq->channels != 1) {
                LOG_ERR("only 1 channel supported");
                return -EINVAL;
        }

        if (seq->resolution != ADS8329_RESOLUTION) {
                LOG_ERR("only supports %u bits resolution (got %" PRIu8 ")",
                        ADS8329_RESOLUTION, seq->resolution);
                return -EINVAL;
        }

        if (seq->oversampling) {
                LOG_ERR("oversampling not supported");
                return -EINVAL;
        }

        if (seq->calibrate) {
                LOG_ERR("read-time calibration unsupported");
                return -EINVAL;
        }

        needed_bytes = sizeof(uint16_t);
        if (opts) {
                needed_bytes *= (1 + opts->extra_samplings);
        }

        if (needed_bytes > seq->buffer_size) {
                LOG_ERR("buffer too small; needs %zu, got %zu", needed_bytes,
                        seq->buffer_size);
                return -ENOSPC;
        }

        return 0;
}

static int ads8329_read(const struct device *dev,
                        const struct adc_sequence *seq)
{
        int status;
        struct ads8329_data *data = dev->data;

        status = ads8329_validate_seq(seq);
        if (status != 0) {
                return status;
        }

        adc_context_lock(&data->ctx, false, NULL);

        data->buffer = seq->buffer;
        adc_context_start_read(&data->ctx, seq);

        status = adc_context_wait_for_completion(&data->ctx);
        adc_context_release(&data->ctx, status);

        return status;
}

static void ads8329_conv_ready_cb(const struct device *port,
                                  struct gpio_callback *cb,
                                  gpio_port_pins_t pins)
{
        ARG_UNUSED(pins);
        ARG_UNUSED(port);

        struct ads8329_data *data =
                CONTAINER_OF(cb, struct ads8329_data, ready_cb);

        adc_context_request_next_sampling(&data->ctx);
}

static void ads8329_read_sample(const struct device *dev)
{
        int status;
        struct ads8329_data *data = dev->data;

        status = ads8329_read_reg(dev, ADS8329_REG_DATA, data->buffer);
        data->buffer += 1;

        if (status != 0) {
                adc_context_complete(&data->ctx, status);
                return;
        }

        adc_context_on_sampling_done(&data->ctx, dev);
}

static void ads8329_aq_thread(void *dev_arg, void *arg2, void *arg3)
{
        ARG_UNUSED(arg2);
        ARG_UNUSED(arg3);

        const struct device *dev = dev_arg;
        struct ads8329_data *data = dev->data;

        for (;;) {
                k_sem_take(&data->sig, K_FOREVER);

                ads8329_read_sample(dev);
        }
}

static DEVICE_API(adc, ads8329_api) = {
        .channel_setup = ads8329_channel_setup,
        .read = ads8329_read,
};

static int ads8329_init(const struct device *dev)
{
        int status;
        k_tid_t tid;
        const struct ads8329_cfg *cfg = dev->config;
        struct ads8329_data *data = dev->data;

        if (!pwm_is_ready_dt(&cfg->pwm_trigger) ||
            !device_is_ready(cfg->ready_gpio.port) ||
            !spi_is_ready_dt(&cfg->spi)) {
                return -EBUSY;
        }

        ads8329_reset(dev);

        adc_context_init(&data->ctx);

        (void)k_sem_init(&data->sig, 0, K_SEM_MAX_LIMIT);

        tid = k_thread_create(&data->aq_thread, data->aq_stack,
                              CONFIG_ADC_ADS8329_THREAD_STACK_SIZE,
                              ads8329_aq_thread, (void *)dev, NULL, NULL,
                              CONFIG_ADC_ADS8329_THREAD_PRIO, 0, K_NO_WAIT);
        k_thread_name_set(tid, "ti_ads8329");

        status = gpio_pin_configure_dt(&cfg->ready_gpio, GPIO_INPUT);
        if (status != 0) {
                return status;
        }

        gpio_init_callback(&data->ready_cb, ads8329_conv_ready_cb,
                           BIT(cfg->ready_gpio.pin));
        status = gpio_add_callback_dt(&cfg->ready_gpio, &data->ready_cb);
        if (status != 0) {
                return status;
        }

        adc_context_unlock_unconditionally(&data->ctx);

        return 0;
}

#define ADS8329_INIT(node_)                                                    \
        static const struct ads8329_cfg ads8329_cfg_##node_##__ = {            \
                .spi = SPI_DT_SPEC_INST_GET(node_,                             \
                                            SPI_MODE_CPOL | SPI_TRANSFER_MSB | \
                                                    SPI_WORD_SET(8),           \
                                            0),                                \
                .pwm_trigger = PWM_DT_SPEC_INST_GET_BY_NAME(node_, timer),     \
                .ready_gpio = GPIO_DT_SPEC_INST_GET(node_, ready_gpios),       \
        };                                                                     \
        static struct ads8329_data ads8329_data_##node_##__ = {                \
                ADC_CONTEXT_INIT_LOCK(ads8329_data_##node_##__, ctx),          \
                ADC_CONTEXT_INIT_SYNC(ads8329_data_##node_##__, ctx),          \
        };                                                                     \
        DEVICE_DT_INST_DEFINE(node_, ads8329_init, NULL,                       \
                              &ads8329_data_##node_##__,                       \
                              &ads8329_cfg_##node_##__, POST_KERNEL,           \
                              CONFIG_ADC_INIT_PRIORITY, &ads8329_api);

DT_INST_FOREACH_STATUS_OKAY(ADS8329_INIT);
