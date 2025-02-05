
#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/adc.h>

#if CONFIG_TOSHIBA_TCD1304_PWM
#include <zephyr/drivers/pwm.h>
#endif

#define DT_DRV_COMPAT toshiba_tcd1304

LOG_MODULE_REGISTER(DT_DRV_COMPAT);

#define TCD1304_MIN_FREQ_HZ (800000)
#define TCD1304_MAX_FREQ_HZ (4000000)

struct tcd1304_cfg {
        const struct gpio_dt_spec gpio_icg;
        const struct gpio_dt_spec gpio_sh;

        const struct adc_dt_spec adc;

#if CONFIG_TOSHIBA_TCD1304_PWM
        uint32_t clock_frequency;
        const struct pwm_dt_spec pwm_master;
#endif
};

struct tcd1304_data {
};

#if CONFIG_TOSHIBA_TCD1304_PWM
static inline uint32_t tcd1304_datarate(const struct device *dev)
{
        const struct tcd1304_cfg *cfg = dev->config;

        return cfg->clock_frequency / 4;
}

static inline uint32_t tcd1304_clock_period_ns(uint32_t freq)
{
        return (uint32_t)(((uint32_t)1e9) / freq);
}
#endif

static int tcd1304_clocks_start(const struct device *dev)
{
#if CONFIG_TOSHIBA_TCD1304_PWM
        int status;
        uint32_t freq;
        uint32_t period;
        const struct tcd1304_cfg *cfg;

        cfg = dev->config;
        freq = cfg->clock_frequency;
        if (freq > TCD1304_MAX_FREQ_HZ || freq < TCD1304_MIN_FREQ_HZ) {
                LOG_ERR("Invalid frequency %" PRIu32, freq);

                return -EINVAL;
        }

        period = tcd1304_clock_period_ns(freq);
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

static int tcd1304_start_capture(const struct device *dev)
{
        int status;
        const struct tcd1304_cfg *cfg;

        cfg = dev->config;

        LOG_ERR("status: %i", status);
        return 0;
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

#if CONFIG_TOSHIBA_TCD1304_PWM
#define TCD1304_CLOCK_CFG(node)                                                \
        .clock_frequency = DT_INST_PROP_OR(node, clock_frequency, 0),          \
        .pwm_master = PWM_DT_SPEC_INST_GET_BY_NAME(node, clock)
#else
#define TCD1304_CLOCK_CFG(node)
#endif

#define TCD1304_INIT(node)                                                     \
        static const struct tcd1304_cfg tcd1304_cfg_##node##__ = {             \
                .gpio_icg = GPIO_DT_SPEC_INST_GET_BY_IDX(node, gpios, 0),      \
                .gpio_sh = GPIO_DT_SPEC_INST_GET_BY_IDX(node, gpios, 1),       \
                .adc = ADC_DT_SPEC_INST_GET(node),                             \
                TCD1304_CLOCK_CFG(node),                                       \
        };                                                                     \
        static struct tcd1304_data tcd1304_data_##node##__;                    \
        DEVICE_DT_INST_DEFINE(node, tcd1304_init, NULL,                        \
                              &tcd1304_data_##node##__,                        \
                              &tcd1304_cfg_##node##__, POST_KERNEL,            \
                              CONFIG_SENSOR_INIT_PRIORITY, NULL);

DT_INST_FOREACH_STATUS_OKAY(TCD1304_INIT);
