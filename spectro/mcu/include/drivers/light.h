
#ifndef DRV_LIGHT_H__
#define DRV_LIGHT_H__

#include <zephyr/device.h>
#include <zephyr/kernel.h>

typedef int (*light_on_t)(const struct device *);
typedef int (*light_off_t)(const struct device *);

__subsystem struct light_driver_api {
        light_on_t light_on;
        light_off_t light_off;
};

/**
 * @brief Turn light source on
 *
 * @param dev
 * @return int
 * @retval -ENOTSUP Driver does not implement `light_on`
 * @retval <0 Negative errno code
 */
__syscall int light_on(const struct device *dev);

static inline int z_impl_light_on(const struct device *dev)
{
        const struct light_driver_api *api = dev->api;
        if (api->light_on == NULL) {
                return -ENOTSUP;
        }

        return api->light_on(dev);
}

/**
 * @brief Turn light source off
 *
 * @param dev
 * @return int
 * @retval -ENOTSUP Driver does not implement `light_off`
 * @retval <0 Negative errno code
 */
__syscall int light_off(const struct device *dev);

static inline int z_impl_light_off(const struct device *dev)
{
        const struct light_driver_api *api = dev->api;
        if (api->light_off == NULL) {
                return -ENOTSUP;
        }

        return api->light_off(dev);
}

#include <zephyr/syscalls/light.h>

#endif /* DRV_LIGHT_H__ */
