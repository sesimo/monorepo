
#include <zephyr/device.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/logging/log.h>

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

        reg = addr << BOFP1_REG_OFFSET;
        if (write) {
                reg |= BOFP1_REG_BIT_WR;

                return spi_write_dt(&cfg->bus, &tx_set);
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

static uint8_t bofp1_clkdiv_from_freq(const struct device *dev, uint32_t freq)
{
        const struct bofp1_cfg *cfg = dev->config;

        return (cfg->clock_frequency - freq * (cfg->psc + 1)) / freq - 1;
}

static uint32_t bofp1_clkdiv_to_freq(const struct device *dev, uint8_t div)
{
        const struct bofp1_cfg *cfg = dev->config;

        return cfg->clock_frequency / (cfg->psc + 1 * div + 1);
}

static int bofp1_attr_get(const struct device *dev, enum sensor_channel chan,
                          enum sensor_attribute attr, struct sensor_value *val)
{
        if (chan != SENSOR_CHAN_VOLTAGE) {
                return -EINVAL;
        }

        switch (attr) {
        case SENSOR_ATTR_SAMPLING_FREQUENCY:
                break;
        case SENSOR_ATTR_BOFP1_INTEGRATION:
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
                break;
        case SENSOR_ATTR_BOFP1_INTEGRATION:
                break;
        default:
                return -EINVAL;
        }

        return 0;
}

static DEVICE_API(sensor, bofp1_api) = {
        .attr_get = bofp1_attr_get,
        .attr_set = bofp1_attr_set,
        .submit = bofp1_submit,
        .get_decoder = bofp1_get_decoder,
};

static int bofp1_init(const struct device *dev)
{
        const struct bofp1_cfg *cfg = dev->config;

        if (!spi_is_ready_dt(&cfg->bus)) {
                return -EBUSY;
        }

        return 0;
}

#define BOFP1_INIT(inst_)                                                      \
        static const struct bofp1_cfg bofp1_cfg_##inst_##__ = {                \
                .bus = SPI_DT_SPEC_INST_GET(                                   \
                        inst_, SPI_MODE_MASTER | SPI_MODE_CPOL, 0),            \
                .psc = DT_INST_PROP(inst_, prescaler),                         \
                .clock_frequency = DT_INST_PROP(inst_, clock_frequency),       \
        };                                                                     \
        static struct bofp1_data bofp1_data_##inst_##__;                       \
        DEVICE_DT_INST_DEFINE(inst_, bofp1_init, NULL,                         \
                              &bofp1_data_##inst_##__, &bofp1_cfg_##inst_##__, \
                              POST_KERNEL, CONFIG_SENSOR_INIT_PRIORITY,        \
                              &bofp1_api);

DT_INST_FOREACH_STATUS_OKAY(BOFP1_INIT);
