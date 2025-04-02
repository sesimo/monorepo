
#include <zephyr/drivers/pwm.h>

#include <drivers/light.h>

#define DT_DRV_COMPAT sesimo_sg90_light

struct sg90_light_cfg {
        struct pwm_dt_spec pwm;
        uint32_t dc_on;
        uint32_t dc_off;
};

struct sg90_light_data {
};

static int sg90_light_on(const struct device *dev)
{
        const struct sg90_light_cfg *cfg = dev->config;
        return pwm_set_pulse_dt(&cfg->pwm, cfg->dc_on);
}

static int sg90_light_off(const struct device *dev)
{
        const struct sg90_light_cfg *cfg = dev->config;
        return pwm_set_pulse_dt(&cfg->pwm, cfg->dc_off);
}

static DEVICE_API(light, sg90_light_api) = {
        .light_on = sg90_light_on,
        .light_off = sg90_light_off,
};

static int sg90_light_init(const struct device *dev)
{
        const struct sg90_light_cfg *cfg = dev->config;

        if (!pwm_is_ready_dt(&cfg->pwm)) {
                return -EBUSY;
        }

        return 0;
}

#define SG90_LIGHT_INIT(node_)                                                 \
        static const struct sg90_light_cfg sg90_light_cfg_##node_##__ = {      \
                .pwm = PWM_DT_SPEC_INST_GET_BY_NAME(node_, pwm),               \
                .dc_off = DT_INST_PROP(node_, dc_off),                         \
                .dc_on = DT_INST_PROP(node_, dc_on),                           \
        };                                                                     \
        static struct sg90_light_data sg90_light_data_##node_##__;             \
        DEVICE_DT_INST_DEFINE(node_, sg90_light_init, NULL,                    \
                              &sg90_light_data_##node_##__,                    \
                              &sg90_light_cfg_##node_##__, POST_KERNEL,        \
                              CONFIG_LIGHT_INIT_PRIORITY, &sg90_light_api)

DT_INST_FOREACH_STATUS_OKAY(SG90_LIGHT_INIT);
