
#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/sys/byteorder.h>

#include <drivers/sensor/bofp1.h>

#include "spectro.h"

#define SPECTRO_DEV DT_CHOSEN(sesimo_bofp1)

LOG_MODULE_REGISTER(spectro);

static uint16_t spectro_buf[3694];

static const struct device *dev = DEVICE_DT_GET(SPECTRO_DEV);

SENSOR_DT_READ_IODEV(iodev, SPECTRO_DEV);
RTIO_DEFINE(rtio_ctx, 1, 1);

struct spectro_q_entry {
        spectro_data_rdy_cb cb;
        void *user_arg;
};

static struct sensor_decode_context decode_ctx = SENSOR_DECODE_CONTEXT_INIT(
        NULL, (uint8_t *)spectro_buf, SENSOR_CHAN_VOLTAGE, 0);

K_MUTEX_DEFINE(lock);

K_MSGQ_DEFINE(msgq, sizeof(struct spectro_q_entry), 2, 1);

/** @brief Convert @p src with shift @p m to a float */
#define Q31_TO_F(src, m) ((float)(((int64_t)src) << m) / (float)(1U << 31))

/** @brief Converts the voltage in @p to millivolts */
static uint16_t convert_voltage(q31_t q, uint8_t shift)
{
        return (uint16_t)(Q31_TO_F(q, shift) * 1000);
}

int spectro_stream_read(void *buf_arg, size_t size_arg, size_t *real_size)
{
        int status;
        uint8_t *buf;
        uint16_t frames;
        size_t size;
        size_t base_size;
        size_t frame_size;
        uint16_t value;
        struct sensor_q31_data data;

        buf = buf_arg;
        size = size_arg;

        (void)k_mutex_lock(&lock, K_FOREVER);

        __ASSERT_NO_MSG(decode_ctx.decoder != NULL);

        status = decode_ctx.decoder->get_frame_count(
                decode_ctx.buffer, decode_ctx.channel, &frames);
        if (status != 0) {
                goto exit;
        }

        status = decode_ctx.decoder->get_size_info(decode_ctx.channel,
                                                   &base_size, &frame_size);
        if (status != 0) {
                goto exit;
        }

        while (size >= sizeof(uint16_t) && frames > 0) {
                status = sensor_decode(&decode_ctx, &data, 1);
                if (status < 0) {
                        goto exit;
                }

                value = convert_voltage(data.readings[0].voltage, data.shift);
                sys_put_be16(value, buf);

                frames -= MIN(status, frames);

                size -= sizeof(uint16_t);
                buf += sizeof(uint16_t);
        }

        *real_size = size_arg - size;

exit:
        (void)k_mutex_unlock(&lock);

        if (status < 0) {
                LOG_WRN("TODO: decode");
                status = 0;
                return status;
        }

        return frames > 0;
}

int spectro_sample(spectro_data_rdy_cb cb, void *user_arg)
{
        struct spectro_q_entry entry = {
                .cb = cb,
                .user_arg = user_arg,
        };

        return k_msgq_put(&msgq, &entry, K_NO_WAIT);
}

static void aq_thread(void *p1, void *p2, void *p3)
{
        int status;
        struct spectro_q_entry entry;

        for (;;) {
                (void)k_msgq_get(&msgq, &entry, K_FOREVER);

                (void)k_mutex_lock(&lock, K_FOREVER);

                status = sensor_get_decoder(dev, &decode_ctx.decoder);
                __ASSERT_NO_MSG(status == 0);

                /* Reset frame iterator */
                decode_ctx.fit = 0;

                status = sensor_read(&iodev, &rtio_ctx, (uint8_t *)spectro_buf,
                                     sizeof(spectro_buf));
                (void)k_mutex_unlock(&lock);

                if (status != 0) {
                        LOG_ERR("read failed: %i", status);
                        continue;
                }

                entry.cb(entry.user_arg);
        }
}

K_THREAD_DEFINE(aq_thread_handle, 256, aq_thread, NULL, NULL, NULL,
                CONFIG_SYSTEM_WORKQUEUE_PRIORITY + 1, 0, 0);
