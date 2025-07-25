
#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/sys/byteorder.h>

#include <drivers/sensor/bofp1.h>

#include "spectro.h"

#define SPECTRO_DEV DT_CHOSEN(sesimo_bofp1)

LOG_MODULE_REGISTER(spectro, LOG_LEVEL_DBG);

static uint16_t spectro_buf[3694];

static const struct device *dev = DEVICE_DT_GET(SPECTRO_DEV);

SENSOR_DT_READ_IODEV(iodev, SPECTRO_DEV);
RTIO_DEFINE(rtio_ctx, 1, 1);

struct spectro_q_entry {
        spectro_data_rdy_cb cb;
        void *user_arg;
};

static const enum sensor_channel channel =
        (enum sensor_channel)SENSOR_CHAN_BOFP1_INTENSITY;
static struct sensor_decode_context decode_ctx =
        SENSOR_DECODE_CONTEXT_INIT(NULL, (uint8_t *)spectro_buf, channel, 0);

K_MUTEX_DEFINE(lock);

K_MSGQ_DEFINE(msgq, sizeof(struct spectro_q_entry), 2, 1);

/** @brief Converts the scale from Q format */
static uint16_t convert_scale(q31_t q, uint8_t shift)
{
        return (uint16_t)(((int64_t)q << shift) / (1ULL << 31));
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

        while (size >= sizeof(uint16_t) && decode_ctx.fit < frames) {
                status = sensor_decode(&decode_ctx, &data, 1);
                if (status <= 0) {
                        /* Checking if empty in the loop condition, so this
                         * should not return 0. */
                        if (status == 0) {
                                status = -ENODATA;
                        }
                        goto exit;
                }

                value = convert_scale(data.readings[0].value, data.shift);
                sys_put_le16(value, buf);

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

        return decode_ctx.fit < frames;
}

int spectro_sample(spectro_data_rdy_cb cb, void *user_arg)
{
        struct spectro_q_entry entry = {
                .cb = cb,
                .user_arg = user_arg,
        };

        if (!device_is_ready(dev)) {
                LOG_ERR("spectrometer driver not initialized");
                return -EBUSY;
        }

        return k_msgq_put(&msgq, &entry, K_NO_WAIT);
}

uint32_t spectro_get_int_time(void)
{
        struct sensor_value val;

        (void)sensor_attr_get(
                dev, channel,
                (enum sensor_attribute)SENSOR_ATTR_BOFP1_INTEGRATION, &val);

        return val.val1 / 1000;
}

int spectro_set_int_time(uint32_t int_us)
{
        int status;
        struct sensor_value val;

        (void)k_mutex_lock(&lock, K_FOREVER);

        val.val1 = int_us * 1000;
        status = sensor_attr_set(
                dev, channel,
                (enum sensor_attribute)SENSOR_ATTR_BOFP1_INTEGRATION, &val);

        (void)k_mutex_unlock(&lock);

        return status;
}

int spectro_set_pipeline_ctrl(uint8_t dc, uint8_t totavg, uint8_t movavg)
{
        int status;
        struct {
                enum sensor_attr_bofp1 attr;
                uint8_t val;
        } values[] = {
                {SENSOR_ATTR_BOFP1_DARK_CURRENT_ENA, dc},
                {SENSOR_ATTR_BOFP1_TOTAL_AVG_ENA, totavg},
                {SENSOR_ATTR_BOFP1_MOVING_AVG_ENA, movavg},
        };
        size_t i;
        struct sensor_value sensor_val;

        (void)k_mutex_lock(&lock, K_FOREVER);

        for (i = 0; i < ARRAY_SIZE(values); i++) {
                sensor_val.val1 = values[i].val;
                status = sensor_attr_set(dev, channel,
                                         (enum sensor_attribute)values[i].attr,
                                         &sensor_val);
                if (status != 0) {
                        break;
                }
        }

        (void)k_mutex_unlock(&lock);

        return status;
}

int spectro_set_moving_avg_n(uint8_t n)
{
        int status;
        struct sensor_value val;
        val.val1 = n;

        (void)k_mutex_lock(&lock, K_FOREVER);

        status = sensor_attr_set(
                dev, channel,
                (enum sensor_attribute)SENSOR_ATTR_BOFP1_MOVING_AVG_N, &val);

        (void)k_mutex_unlock(&lock);

        return status;
}

int spectro_set_total_avg_n(uint8_t n)
{
        int status;
        struct sensor_value val;
        val.val1 = n;

        (void)k_mutex_lock(&lock, K_FOREVER);

        status = sensor_attr_set(
                dev, channel,
                (enum sensor_attribute)SENSOR_ATTR_BOFP1_TOTAL_AVG_N, &val);

        (void)k_mutex_unlock(&lock);

        return status;
}

static void aq_thread(void *p1, void *p2, void *p3)
{
        int status;
        struct spectro_q_entry entry;

        for (;;) {
                (void)k_msgq_get(&msgq, &entry, K_FOREVER);
                LOG_DBG("acquiring sample");

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

                LOG_DBG("sample completed");
                entry.cb(entry.user_arg);
        }
}

K_THREAD_DEFINE(aq_thread_handle, 512, aq_thread, NULL, NULL, NULL,
                CONFIG_SYSTEM_WORKQUEUE_PRIORITY + 1, 0, 0);
