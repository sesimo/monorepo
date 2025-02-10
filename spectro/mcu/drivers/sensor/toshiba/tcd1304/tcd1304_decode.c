
#include <drivers/sensor/tcd1304.h>

static int tcd1304_get_frame_count(const uint8_t *buffer,
                                   struct sensor_chan_spec channel,
                                   uint16_t *frame_count)
{
        ARG_UNUSED(channel);
        ARG_UNUSED(buffer);
        ARG_UNUSED(frame_count);

        return -ENOTSUP;
}

static int tcd1304_get_size_info(struct sensor_chan_spec channel,
                                 size_t *base_size, size_t *frame_size)
{
        ARG_UNUSED(channel);
        ARG_UNUSED(base_size);
        ARG_UNUSED(frame_size);

        return -ENOTSUP;
}

static int tcd1304_decode(const uint8_t *buffer,
                          struct sensor_chan_spec channel, uint32_t *fit,
                          uint16_t max_count, void *data_out)
{
        ARG_UNUSED(buffer);
        ARG_UNUSED(channel);
        ARG_UNUSED(fit);
        ARG_UNUSED(max_count);
        ARG_UNUSED(data_out);

        return -ENOTSUP;
}

static bool tcd1304_has_trigger(const uint8_t *buffer,
                                enum sensor_trigger_type trigger)
{
        return false;
}

SENSOR_DECODER_API_DT_DEFINE() = {
        .has_trigger = tcd1304_has_trigger,
        .decode = tcd1304_decode,
        .get_size_info = tcd1304_get_size_info,
        .get_frame_count = tcd1304_get_frame_count,
};

int tcd1304_get_decoder(const struct device *dev,
                        const struct sensor_decoder_api **api)
{
        ARG_UNUSED(dev);

        *api = &SENSOR_DECODER_NAME();
        return 0;
}
