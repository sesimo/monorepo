
#include <zephyr/drivers/sensor.h>

#include "bofp1.h"

SENSOR_DECODER_API_DT_DEFINE() = {};

int bofp1_get_decoder(const struct device *dev,
                      const struct sensor_decoder_api **decoder)
{
        ARG_UNUSED(dev);

        *decoder = &SENSOR_DECODER_NAME();

        return 0;
}
