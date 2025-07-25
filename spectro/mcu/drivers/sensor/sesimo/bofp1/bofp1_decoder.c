
#include <zephyr/drivers/sensor.h>
#include <zephyr/sys/byteorder.h>

#include <drivers/sensor/bofp1.h>

#include "bofp1.h"

static q31_t to_q31(uint16_t value, int shift)
{
        /* Convert to Q31 format to conform to the sensor API */
        int64_t upscaled = (int64_t)value * INT64_C(1ULL << 31);
        int64_t shifted = upscaled >> shift;

        return CLAMP(shifted, INT32_MIN, INT32_MAX);
}

static int bofp1_decode(const uint8_t *buf, struct sensor_chan_spec chan,
                        uint32_t *fit, uint16_t max_count, void *data_out)
{
        struct sensor_q31_data *data = data_out;
        const uint8_t *ptr;
        uint16_t value;

        if (chan.chan_type !=
                    (enum sensor_channel)SENSOR_CHAN_BOFP1_INTENSITY ||
            chan.chan_idx != 0) {
                return -ENOTSUP;
        }

        if (*fit >= BOFP1_NUM_ELEMENTS) {
                return 0;
        }

        ptr = buf + sizeof(struct bofp1_rtio_header) + *fit * sizeof(uint16_t);
        value = sys_get_be16(ptr);

        data->shift = 16;
        data->readings[0].value = to_q31(value, data->shift);

        *fit += 1;

        return 1;
}

static int bofp1_get_size_info(struct sensor_chan_spec chan, size_t *base_size,
                               size_t *frame_size)
{
        if (chan.chan_type !=
                    (enum sensor_channel)SENSOR_CHAN_BOFP1_INTENSITY ||
            chan.chan_idx != 0) {
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
        struct bofp1_rtio_header header;

        if (chan.chan_type !=
                    (enum sensor_channel)SENSOR_CHAN_BOFP1_INTENSITY ||
            chan.chan_idx != 0) {
                return -ENOTSUP;
        }

        (void)memcpy(&header, buf, sizeof(header));

        /* Driver currently only supports a full, constant-length readout */
        *frame_count = header.frames;
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
