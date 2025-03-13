
#include <zephyr/drivers/sensor.h>

#include "bofp1.h"

static q31_t to_q31(uint16_t value, int shift)
{
        int64_t inter =
                ((int64_t)value * (1 << 31)) / ((1 << shift) * INT64_C(1000));

        return CLAMP(inter, INT32_MIN, INT32_MAX);
}

static int bofp1_decode(const uint8_t *buf, struct sensor_chan_spec chan,
                        uint32_t *fit, uint16_t max_count, void *data_out)
{
        struct sensor_q31_data *data = data_out;

        if (chan.chan_type != SENSOR_CHAN_VOLTAGE || chan.chan_idx != 0) {
                return -ENOTSUP;
        }

        if (*fit >= BOFP1_NUM_ELEMENTS_REAL) {
                return 0;
        }

        static int volt = 0;
        data->shift = 0;
        data->readings[0].voltage = to_q31(volt++, data->shift);

        *fit += 1;

        return 1;
}

static int bofp1_get_size_info(struct sensor_chan_spec chan, size_t *base_size,
                               size_t *frame_size)
{
        if (chan.chan_type != SENSOR_CHAN_VOLTAGE || chan.chan_idx != 0) {
                return -ENOTSUP;
        }

        *base_size = sizeof(struct sensor_q31_data);
        *frame_size = sizeof(struct sensor_q31_sample_data);

        return 0;
}

static int bofp1_get_frame_count(const uint8_t *buf,
                                 struct sensor_chan_spec chan,
                                 uint16_t *frame_count)
{
        ARG_UNUSED(buf);

        if (chan.chan_type != SENSOR_CHAN_VOLTAGE || chan.chan_idx != 0) {
                return -ENOTSUP;
        }

        /* Driver currently only supports a full, constant-length readout */
        *frame_count = BOFP1_NUM_ELEMENTS_REAL;
        return 0;
}

SENSOR_DECODER_API_DT_DEFINE() = {
        .decode = bofp1_decode,
        .get_size_info = bofp1_get_size_info,
        .get_frame_count = bofp1_get_frame_count,
};

int bofp1_get_decoder(const struct device *dev,
                      const struct sensor_decoder_api **decoder)
{
        ARG_UNUSED(dev);

        *decoder = &SENSOR_DECODER_NAME();

        return 0;
}
