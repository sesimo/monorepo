
#include <zephyr/device.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/gpio.h>

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
        struct bofp1_data *data = dev->data;
        const struct bofp1_cfg *cfg = dev->config;

        return cfg->clock_frequency /
               (BOFP1_CLKDIV_MIN + BOFP1_CLKDIV_DERIV * data->clkdiv);
}

static uint32_t bofp1_mclk_div(const struct device *dev, uint32_t freq)
{
        const struct bofp1_cfg *cfg = dev->config;

        return cfg->clock_frequency / (BOFP1_CLKDIV_DERIV * freq) -
               BOFP1_CLKDIV_MIN / BOFP1_CLKDIV_DERIV;
}

static uint32_t bofp1_psc_freq(const struct device *dev)
{
        const struct bofp1_cfg *cfg = dev->config;

        return bofp1_mclk_freq(dev) / (cfg->psc + 1);
}

static uint8_t bofp1_clkdiv_packed(uint8_t clkdiv, uint8_t psc)
{
        return (psc << BOFP1_PSC_INDEX) | (clkdiv << BOFP1_CLKDIV_INDEX);
}

static int bofp1_set_sample_div(const struct device *dev, uint8_t div)
{
        uint8_t packed;
        int status;
        const struct bofp1_cfg *cfg = dev->config;
        struct bofp1_data *data = dev->data;

        packed = bofp1_clkdiv_packed(div, cfg->psc);
        status = bofp1_write_reg(dev, BOFP1_REG_CLKDIV, packed);
        if (status != 0) {
                return status;
        }

        data->clkdiv = div;

        return 0;
}

static int bofp1_set_sample_freq(const struct device *dev, uint32_t freq)
{
        uint32_t mclk_freq = freq * BOFP1_DATA_CLKDIV;

        return bofp1_set_sample_div(dev, bofp1_mclk_div(dev, mclk_freq));
}

static uint8_t bofp1_sh_div(const struct device *dev, uint32_t freq)
{
        return (bofp1_psc_freq(dev) / freq) - 1;
}

static uint32_t bofp1_integration_time(const struct device *dev, uint8_t div)
{
        return 1000000000UL / (bofp1_psc_freq(dev) / (div + 1));
}

static int bofp1_set_integration_time(const struct device *dev,
                                      uint32_t time_ns)
{
        uint32_t freq;
        uint8_t div;
        int status;
        struct bofp1_data *data = dev->data;

        freq = 1000000000UL / time_ns;
        if (freq > bofp1_psc_freq(dev)) {
                LOG_ERR("Integration time frequency must be lower than "
                        "prescaled frequency. Consider adjusting the "
                        "prescaler");
                return -EINVAL;
        }

        div = bofp1_sh_div(dev, freq);

        status = bofp1_write_reg(dev, BOFP1_REG_CCD_SH, div);
        if (status != 0) {
                return status;
        }

        data->shdiv = div;
        return 0;
}

int bofp1_reset(const struct device *dev)
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

        switch (attr) {
        case SENSOR_ATTR_SAMPLING_FREQUENCY:
                val->val1 = (int32_t)bofp1_mclk_freq(dev) / BOFP1_DATA_CLKDIV;
                break;
        case SENSOR_ATTR_BOFP1_INTEGRATION:
                val->val1 = bofp1_integration_time(dev, data->shdiv);
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
        if (chan != SENSOR_CHAN_VOLTAGE) {
                return -EINVAL;
        }

        switch (attr) {
        case SENSOR_ATTR_SAMPLING_FREQUENCY:
                return bofp1_set_sample_freq(dev, (uint32_t)val->val1);
        case SENSOR_ATTR_BOFP1_INTEGRATION:
                return bofp1_set_integration_time(dev, (uint32_t)val->val1);
        default:
                return -EINVAL;
        }

        return 0;
}

int bofp1_enable_read(const struct device *dev)
{
        int status;
        const struct bofp1_cfg *cfg = dev->config;

        status = gpio_pin_interrupt_configure_dt(&cfg->fifo_w_gpios,
                                                 GPIO_INT_EDGE_TO_ACTIVE);

        return status;
}

int bofp1_disable_read(const struct device *dev)
{
        int status;
        const struct bofp1_cfg *cfg = dev->config;

        status = gpio_pin_interrupt_configure_dt(&cfg->fifo_w_gpios,
                                                 GPIO_INT_DISABLE);

        return status;
}

static void bofp1_busy_fall_cb(const struct device *gpio,
                               struct gpio_callback *cb, gpio_port_pins_t pins)
{
        struct bofp1_data *data;

        ARG_UNUSED(gpio);
        ARG_UNUSED(pins);

        data = CONTAINER_OF(cb, struct bofp1_data, busy_fall_cb);

        if (!atomic_test_and_clear_bit(&data->state, BOFP1_BUSY)) {
                return;
        }

        LOG_ERR("sampling done");

        bofp1_rtio_read(data->dev);
}

static void bofp1_fifo_wmark_cb(const struct device *gpio,
                                struct gpio_callback *cb, gpio_port_pins_t pins)
{
        struct bofp1_data *data;

        ARG_UNUSED(gpio);
        ARG_UNUSED(pins);

        LOG_ERR("fifo watermark hit");

        data = CONTAINER_OF(cb, struct bofp1_data, fifo_w_cb);
        bofp1_rtio_read(data->dev);
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

        if (!spi_is_ready_dt(&cfg->bus)) {
                return -EBUSY;
        }

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

        status = bofp1_set_sample_div(dev, cfg->clkdiv_dt);
        if (status != 0) {
                LOG_ERR("unable to set sampling div: %i", status);
                return status;
        }

        status = bofp1_set_integration_time(dev, cfg->integration_time_dt);
        if (status != 0) {
                LOG_ERR("unable to set integration time: %i", status);
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
                .psc = DT_INST_PROP(inst_, prescaler),                         \
                .clkdiv_dt = DT_INST_PROP(inst_, clkdiv),                      \
                .integration_time_dt = DT_INST_PROP(inst_, integration_time),  \
                .busy_gpios = GPIO_DT_SPEC_INST_GET(inst_, busy_gpios),        \
                .fifo_w_gpios =                                                \
                        GPIO_DT_SPEC_INST_GET(inst_, fifo_wmark_gpios),        \
                .clock_frequency = DT_INST_PROP(inst_, clock_frequency),       \
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
