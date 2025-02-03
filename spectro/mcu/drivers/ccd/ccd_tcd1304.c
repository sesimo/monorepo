
#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#if CONFIG_TOSHIBA_TCD1304_PWM
#include <zephyr/drivers/pwm.h>
#endif

#define DT_DRV_COMPAT toshiba_tcd1304

LOG_MODULE_REGISTER(DT_DRV_COMPAT);

#define TCD1304_ADC_STCONV_TIME_NS (200)
#define TCD1304_MIN_FREQ_HZ        (800000)
#define TCD1304_MAX_FREQ_HZ        (4000000)

struct tcd1304_cfg {
#if CONFIG_TOSHIBA_TCD1304_PWM
        uint32_t clock_frequency;
        const struct pwm_dt_spec pwm_master;
        const struct pwm_dt_spec pwm_trigger;
#endif
};

struct tcd1304_data {
};

#if CONFIG_TOSHIBA_TCD1304_PWM
static inline uint32_t tcd1304_datarate(uint32_t freq)
{
        return freq / 4;
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
        uint32_t datarate;
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

        datarate = tcd1304_datarate(freq);
        period = tcd1304_clock_period_ns(datarate);

        status = pwm_set_dt(&cfg->pwm_trigger, period,
                            TCD1304_ADC_STCONV_TIME_NS);
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

        status = pwm_set_dt(&cfg->pwm_trigger, 0, 0);
        if (status != 0) {
                return status;
        }

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

static int tcd1304_init(const struct device *dev)
{
        int status;
        const struct tcd1304_cfg *cfg;
        struct tcd1304_data *data;

        cfg = dev->config;
        data = dev->data;

        if (!device_is_ready(cfg->pwm_master.dev) ||
            !device_is_ready(cfg->pwm_trigger.dev)) {
                return -EBUSY;
        }

        status = tcd1304_clocks_start(dev);
        __ASSERT_NO_MSG(status == 0);
        k_sleep(K_SECONDS(10));
        status = tcd1304_clocks_stop(dev);
        __ASSERT_NO_MSG(status == 0);

        return 0;
}

#if CONFIG_TOSHIBA_TCD1304_PWM
#define TCD1304_CLOCK_CFG(node)                                                \
        .clock_frequency = DT_INST_PROP_OR(node, clock_frequency, 0),          \
        .pwm_master = PWM_DT_SPEC_INST_GET_BY_NAME(node, master),              \
        .pwm_trigger = PWM_DT_SPEC_INST_GET_BY_NAME(node, trigger)
#else
#define TCD1304_CLOCK_CFG(node)
#endif

#define TCD1304_INIT(node)                                                     \
        static const struct tcd1304_cfg tcd1304_cfg_##node##__ = {             \
                TCD1304_CLOCK_CFG(node),                                       \
        };                                                                     \
        DEVICE_DT_INST_DEFINE(node, tcd1304_init, NULL, NULL,                  \
                              &tcd1304_cfg_##node##__, POST_KERNEL, 99, NULL);

DT_INST_FOREACH_STATUS_OKAY(TCD1304_INIT);
