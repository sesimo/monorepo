
#include <zephyr/device.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/byteorder.h>

#include <drivers/sensor/bofp1.h>

#include "bofp1.h"

#define DT_DRV_COMPAT sesimo_bofp1

LOG_MODULE_REGISTER(DT_DRV_COMPAT);

int bofp1_access(const struct device *dev, bool write, uint8_t addr, void *data,
                 size_t size)
{
        uint8_t reg;
        const struct bofp1_cfg *cfg = dev->config;
        struct spi_buf bufs[] = {
                {
                        .buf = &reg,
                        .len = 1,
                },
                {
                        .buf = data,
                        .len = size,
                },
        };
        struct spi_buf_set tx_set = {
                .buffers = bufs,
                .count = write ? 2 : 1,
        };
        struct spi_buf_set rx_set = {
                .buffers = bufs,
                .count = ARRAY_SIZE(bufs),
        };

        if (write) {
                reg = BOFP1_WRITE_REG(addr);

                return spi_write_dt(&cfg->bus, &tx_set);
        } else {
                reg = BOFP1_READ_REG(addr);
        }

        return spi_transceive_dt(&cfg->bus, &tx_set, &rx_set);
}

int bofp1_write_reg(const struct device *dev, uint8_t addr, uint8_t value)
{
        return bofp1_access(dev, true, addr, &value, sizeof(value));
}

int bofp1_stream(const struct device *dev, void *data, size_t size)
{
        return bofp1_access(dev, false, BOFP1_REG_STREAM, data, size);
}

int bofp1_read_reg(const struct device *dev, uint8_t addr, uint8_t *value)
{
        return bofp1_access(dev, false, addr, value, sizeof(*value));
}

static uint32_t bofp1_mclk_freq(const struct device *dev)
{
        const struct bofp1_cfg *cfg = dev->config;

        return cfg->clock_frequency / cfg->clkdiv;
}

static uint32_t bofp1_sample_freq(const struct device *dev)
{
        return bofp1_mclk_freq(dev) / 4;
}

static uint32_t bofp1_sh_div(const struct device *dev, uint32_t freq)
{
        return (bofp1_mclk_freq(dev) / freq) - 1;
}

static uint32_t bofp1_integration_time(const struct device *dev)
{
        struct bofp1_data *data = dev->data;
        uint32_t div;

        div = sys_get_be24(data->shdiv);

        return 1000000000UL / (bofp1_mclk_freq(dev) / (div + 1));
}

static int bofp1_set_integration_time(const struct device *dev,
                                      uint32_t time_ns)
{
        uint32_t freq;
        uint32_t div;
        int status;
        struct bofp1_data *data = dev->data;
        k_spinlock_key_t key;

        key = k_spin_lock(&data->lock);

        freq = 1000000000UL / time_ns;
        if (freq == 0) {
                LOG_ERR("Integration time %" PRIu32 " is too high.", time_ns);
                status = -EINVAL;
                goto exit;
        }

        div = bofp1_sh_div(dev, freq);
        if (div > (1 << 24) - 1) {
                LOG_ERR("Integration time %" PRIu32 " is too high.", time_ns);
                status = -EINVAL;
                goto exit;
        }

        sys_put_be24(div, data->shdiv);

        status = bofp1_write_reg(dev, BOFP1_REG_CCD_SH1, data->shdiv[0]);
        if (status != 0) {
                goto exit;
        }

        status = bofp1_write_reg(dev, BOFP1_REG_CCD_SH2, data->shdiv[1]);
        if (status != 0) {
                goto exit;
        }

        status = bofp1_write_reg(dev, BOFP1_REG_CCD_SH3, data->shdiv[2]);
        if (status != 0) {
                goto exit;
        }

exit:
        k_spin_unlock(&data->lock, key);

        return status;
}

static int bofp1_set_reg(const struct device *dev, uint8_t reg, uint8_t val)
{
        int status;
        uint8_t check;

        status = bofp1_write_reg(dev, reg, val);
        if (status != 0) {
                return status;
        }

        status = bofp1_read_reg(dev, reg, &check);
        if (status != 0) {
                return status;
        } else if (check != val) {
                LOG_ERR("Unable to set register; returned value did not match "
                        "desired value");
                return -EIO;
        }

        LOG_DBG("set register %d to %d", reg, val);

        return 0;
}

static int bofp1_set_moving_avg_n(const struct device *dev, uint8_t n)
{
        int status = 0;
        struct bofp1_data *data = dev->data;

        K_SPINLOCK(&data->lock)
        {
                status = bofp1_set_reg(dev, BOFP1_REG_MOVING_AVG_N, n);
                data->moving_avg_n = status == 0 ? n : 0;
        }

        return status;
}

static int bofp1_set_total_avg_n(const struct device *dev, uint8_t n)
{
        int status = 0;
        struct bofp1_data *data = dev->data;

        K_SPINLOCK(&data->lock)
        {
                status = bofp1_set_reg(dev, BOFP1_REG_TOTAL_AVG_N, n);
                data->total_avg_n = status == 0 ? n : 0;
        }

        return status;
}

static int bofp1_set_prc(const struct device *dev, bool dc_ena, bool movavg_ena,
                         bool totavg_ena)
{
        int status = 0;
        uint8_t val;
        struct bofp1_data *data = dev->data;

        val = (dc_ena << BOFP1_PRC_DC_ENA) |
              (movavg_ena << BOFP1_PRC_MOVAVG_ENA) |
              (totavg_ena << BOFP1_PRC_TOTAVG_ENA);

        K_SPINLOCK(&data->lock)
        {
                status = bofp1_set_reg(dev, BOFP1_REG_PRCCTRL, val);
                data->prc = status == 0 ? val : 0;
        }

        return status;
}

uint8_t bofp1_get_prc(const struct device *dev, unsigned int bit)
{
        struct bofp1_data *data = dev->data;

        return (data->prc >> bit) & 0x1;
}

static int bofp1_reset(const struct device *dev)
{
        return bofp1_write_reg(dev, BOFP1_REG_RESET, 0);
}

static int bofp1_attr_get(const struct device *dev, enum sensor_channel chan,
                          enum sensor_attribute attr, struct sensor_value *val)
{
        struct bofp1_data *data = dev->data;

        if (chan != SENSOR_CHAN_VOLTAGE) {
                return -EINVAL;
        }

        switch ((enum sensor_attr_bofp1)attr) {
        case SENSOR_ATTR_BOFP1_INTEGRATION:
                val->val1 = bofp1_integration_time(dev);
                break;
        case SENSOR_ATTR_BOFP1_MOVING_AVG_N:
                val->val1 = data->moving_avg_n;
                break;
        case SENSOR_ATTR_BOFP1_TOTAL_AVG_N:
                val->val1 = data->total_avg_n;
                break;
        case SENSOR_ATTR_BOFP1_DARK_CURRENT_ENA:
                val->val1 = bofp1_get_prc(dev, BOFP1_PRC_DC_ENA);
                break;
        case SENSOR_ATTR_BOFP1_MOVING_AVG_ENA:
                val->val1 = bofp1_get_prc(dev, BOFP1_PRC_MOVAVG_ENA);
                break;
        case SENSOR_ATTR_BOFP1_TOTAL_AVG_ENA:
                val->val1 = bofp1_get_prc(dev, BOFP1_PRC_TOTAVG_ENA);
                break;
        default:
                return -EINVAL;
        }

        return 0;
}

static int bofp1_attr_set(const struct device *dev, enum sensor_channel chan,
                          enum sensor_attribute attr,
                          const struct sensor_value *val)
{
        uint8_t dc_ena;
        uint8_t movavg_ena;
        uint8_t totavg_ena;

        if (chan != SENSOR_CHAN_VOLTAGE) {
                return -EINVAL;
        }

        dc_ena = bofp1_get_prc(dev, BOFP1_PRC_DC_ENA);
        movavg_ena = bofp1_get_prc(dev, BOFP1_PRC_MOVAVG_ENA);
        totavg_ena = bofp1_get_prc(dev, BOFP1_PRC_TOTAVG_ENA);

        switch ((enum sensor_attr_bofp1)attr) {
        case SENSOR_ATTR_BOFP1_INTEGRATION:
                return bofp1_set_integration_time(dev, (uint32_t)val->val1);
        case SENSOR_ATTR_BOFP1_MOVING_AVG_N:
                return bofp1_set_moving_avg_n(dev, (uint8_t)val->val1);
        case SENSOR_ATTR_BOFP1_TOTAL_AVG_N:
                return bofp1_set_total_avg_n(dev, (uint8_t)val->val1);
        case SENSOR_ATTR_BOFP1_DARK_CURRENT_ENA:
                return bofp1_set_prc(dev, val->val1, movavg_ena, totavg_ena);
        case SENSOR_ATTR_BOFP1_MOVING_AVG_ENA:
                return bofp1_set_prc(dev, dc_ena, val->val1, totavg_ena);
        case SENSOR_ATTR_BOFP1_TOTAL_AVG_ENA:
                return bofp1_set_prc(dev, dc_ena, movavg_ena, val->val1);
        default:
                return -EINVAL;
        }

        return 0;
}

static k_timeout_t bofp1_timeout(const struct device *dev)
{
        uint64_t ns;
        uint32_t frame_duration;
        struct bofp1_data *data = dev->data;

        /* Timeout of integration time * N + 5ms.
         * This is done because the CCD driver on the FPGA synchronizes to
         * the integration time, and may not start until after the
         * integration time has passed. If total averages is enabled,
         * this repeats N times. It will then use roughly 5ms to
         * collect 1024 samples, which is more than what we need. */
        frame_duration =
                1000000000ULL / bofp1_sample_freq(dev) * BOFP1_NUM_ELEMENTS;
        ns = bofp1_integration_time(dev) + frame_duration;
        if (bofp1_get_prc(dev, BOFP1_PRC_TOTAVG_ENA)) {
                ns += (data->total_avg_n) * (frame_duration + ns);
        }
        ns += 5000000;

        return K_NSEC(ns);
}

int bofp1_enable_read(const struct device *dev)
{
        int status;
        const struct bofp1_cfg *cfg = dev->config;
        struct bofp1_data *data = dev->data;

        status = gpio_pin_interrupt_configure_dt(&cfg->fifo_w_gpios,
                                                 GPIO_INT_EDGE_TO_ACTIVE);
        k_work_reschedule(&data->watchdog_work, bofp1_timeout(dev));

        return status;
}

int bofp1_disable_read(const struct device *dev)
{
        int status;
        const struct bofp1_cfg *cfg = dev->config;
        struct bofp1_data *data = dev->data;

        k_work_cancel_delayable(&data->watchdog_work);

        status = gpio_pin_interrupt_configure_dt(&cfg->fifo_w_gpios,
                                                 GPIO_INT_DISABLE);

        return status;
}

static void bofp1_busy_fall(const struct device *dev)
{
        struct bofp1_data *data = dev->data;

        if (!atomic_test_and_clear_bit(&data->state, BOFP1_BUSY)) {
                return;
        }

        LOG_INF("busy fall");

        bofp1_rtio_complete(data->dev);
}

static void bofp1_busy_fall_cb(const struct device *gpio,
                               struct gpio_callback *cb, gpio_port_pins_t pins)
{
        struct bofp1_data *data;

        ARG_UNUSED(gpio);
        ARG_UNUSED(pins);

        data = CONTAINER_OF(cb, struct bofp1_data, busy_fall_cb);

        bofp1_busy_fall(data->dev);
}

static void bofp1_fifo_wmark(const struct device *dev)
{
        struct bofp1_data *data = dev->data;

        LOG_INF("fifo watermark hit");

        if (!atomic_test_bit(&data->state, BOFP1_BUSY)) {
                LOG_ERR("fifo wmark when not busy");
                return;
        }

        bofp1_rtio_read(data->dev);
}

static void bofp1_fifo_wmark_cb(const struct device *gpio,
                                struct gpio_callback *cb, gpio_port_pins_t pins)
{
        struct bofp1_data *data;

        ARG_UNUSED(gpio);
        ARG_UNUSED(pins);

        data = CONTAINER_OF(cb, struct bofp1_data, fifo_w_cb);

        bofp1_fifo_wmark(data->dev);
}

bool bofp1_gpio_check(const struct device *dev)
{
        const struct bofp1_cfg *cfg = dev->config;

        if (gpio_pin_get_dt(&cfg->busy_gpios) == 0) {
                bofp1_busy_fall(dev);
        } else if (gpio_pin_get_dt(&cfg->fifo_w_gpios) > 0) {
                bofp1_fifo_wmark(dev);
        } else {
                return false;
        }

        return true;
}

static DEVICE_API(sensor, bofp1_api) = {
        .attr_get = bofp1_attr_get,
        .attr_set = bofp1_attr_set,
        .submit = bofp1_submit,
        .get_decoder = bofp1_get_decoder,
};

static int bofp1_init_gpio(const struct gpio_dt_spec *spec,
                           gpio_callback_handler_t cb_func,
                           struct gpio_callback *cb, uint8_t pin)
{
        int status;

        if (!gpio_is_ready_dt(spec)) {
                return -EBUSY;
        }

        status = gpio_pin_configure_dt(spec, GPIO_INPUT);
        if (status != 0) {
                return status;
        }

        gpio_init_callback(cb, cb_func, pin);
        status = gpio_add_callback_dt(spec, cb);
        if (status != 0) {
                return status;
        }

        return status;
}

static int bofp1_init(const struct device *dev)
{
        int status;
        const struct bofp1_cfg *cfg = dev->config;
        struct bofp1_data *data = dev->data;

        if (!spi_is_ready_dt(&cfg->bus) || !device_is_ready(cfg->light)) {
                return -EBUSY;
        }

        (void)bofp1_rtio_init(dev);

        status = bofp1_init_gpio(&cfg->busy_gpios, bofp1_busy_fall_cb,
                                 &data->busy_fall_cb, BIT(cfg->busy_gpios.pin));
        if (status != 0) {
                return status;
        }

        status = bofp1_init_gpio(&cfg->fifo_w_gpios, bofp1_fifo_wmark_cb,
                                 &data->fifo_w_cb, BIT(cfg->fifo_w_gpios.pin));
        if (status != 0) {
                return status;
        }

        /* Busy interrupt should always be enabled */
        status = gpio_pin_interrupt_configure_dt(&cfg->busy_gpios,
                                                 GPIO_INT_EDGE_TO_INACTIVE);
        if (status != 0) {
                return status;
        }

        status = bofp1_reset(dev);
        if (status != 0) {
                LOG_ERR("reset failed: %i", status);
                return status;
        }

        status = bofp1_set_integration_time(dev, cfg->integration_time_dt);
        if (status != 0) {
                LOG_ERR("unable to set integration time: %i", status);
                return status;
        }

        status = bofp1_set_total_avg_n(dev, cfg->total_avg_n_dt);
        if (status != 0) {
                return status;
        }

        status = bofp1_set_moving_avg_n(dev, cfg->moving_avg_n_dt);
        if (status != 0) {
                return status;
        }

        status = bofp1_set_prc(dev, cfg->dc_dt, cfg->movavg_dt, cfg->totavg_dt);
        if (status != 0) {
                return status;
        }

        return 0;
}

#define BOFP1_SPI_OP    (SPI_MODE_CPHA | SPI_WORD_SET(8) | SPI_TRANSFER_MSB)
#define BOFP1_SPI_DELAY (1)

#define BOFP1_INIT(inst_)                                                      \
        SPI_DT_IODEV_DEFINE(bofp1_iodev_##inst_##__, DT_DRV_INST(inst_),       \
                            BOFP1_SPI_OP, BOFP1_SPI_DELAY);                    \
        RTIO_DEFINE(bofp1_rtio_##inst_##__, 64, 64);                           \
        static const struct bofp1_cfg bofp1_cfg_##inst_##__ = {                \
                .bus = SPI_DT_SPEC_INST_GET(inst_, BOFP1_SPI_OP,               \
                                            BOFP1_SPI_DELAY),                  \
                .clkdiv = DT_INST_PROP(inst_, clkdiv),                         \
                .integration_time_dt = DT_INST_PROP(inst_, integration_time),  \
                .busy_gpios = GPIO_DT_SPEC_INST_GET(inst_, busy_gpios),        \
                .fifo_w_gpios =                                                \
                        GPIO_DT_SPEC_INST_GET(inst_, fifo_wmark_gpios),        \
                .clock_frequency = DT_INST_PROP(inst_, clock_frequency),       \
                .moving_avg_n_dt = DT_INST_PROP(inst_, moving_avg_n),          \
                .total_avg_n_dt = DT_INST_PROP(inst_, total_avg_n),            \
                .totavg_dt = DT_INST_PROP(inst_, total_avg),                   \
                .movavg_dt = DT_INST_PROP(inst_, moving_avg),                  \
                .dc_dt = DT_INST_PROP(inst_, dark_current),                    \
                .light = DEVICE_DT_GET(DT_INST_PHANDLE(inst_, light)),         \
        };                                                                     \
        static struct bofp1_data bofp1_data_##inst_##__ = {                    \
                .iodev_bus = &bofp1_iodev_##inst_##__,                         \
                .rtio_ctx = &bofp1_rtio_##inst_##__,                           \
                .dev = DEVICE_DT_INST_GET(inst_),                              \
        };                                                                     \
        DEVICE_DT_INST_DEFINE(inst_, bofp1_init, NULL,                         \
                              &bofp1_data_##inst_##__, &bofp1_cfg_##inst_##__, \
                              POST_KERNEL, CONFIG_SENSOR_INIT_PRIORITY,        \
                              &bofp1_api);

DT_INST_FOREACH_STATUS_OKAY(BOFP1_INIT);
