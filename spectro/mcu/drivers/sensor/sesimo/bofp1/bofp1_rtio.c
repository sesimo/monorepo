
#include <zephyr/rtio/rtio.h>
#include <zephyr/rtio/work.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/sensor.h>

#include <drivers/light.h>

#include "bofp1.h"

LOG_MODULE_DECLARE(sesimo_bofp1);

#define READ_CHUNK_SIZE (1024 * sizeof(uint16_t))
#define LIGHT_TIMEOUT   (K_MSEC(300))

static void bofp1_finish(const struct device *dev, int status);

static void bofp1_rtio_err(struct rtio *r, const struct rtio_sqe *sqe,
                           void *dev_arg);

static inline size_t bofp1_frame_size(const struct device *dev)
{
        struct bofp1_data *data = dev->data;
        size_t ret;

        ret = BOFP1_NUM_ELEMENTS;
        if (bofp1_get_prc(dev, BOFP1_PRC_MOVAVG_ENA)) {
                ret -= data->moving_avg_n * 2 + 1;
        }

        return ret * sizeof(uint16_t);
}

static void bofp1_set_status(const struct device *dev, int status)
{
        struct bofp1_data *data = dev->data;

        if (!atomic_cas(&data->status, 0, status)) {
                LOG_WRN("unable to set status; already set");
        }
}

static void bofp1_dc_calib_done(struct rtio_iodev_sqe *iodev_sqe)
{
        int status;
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        const struct device *dev = config->sensor;
        struct bofp1_data *data = dev->data;
        const struct bofp1_cfg *cfg = dev->config;

        /* Busy should be cleared by the ISR/GPIO callback, before submitting
         * this callback to the work queue. If it is set, something strange
         * has happened. */
        if (atomic_test_bit(&data->state, BOFP1_BUSY) ||
            !atomic_test_and_clear_bit(&data->state, BOFP1_DC_CALIB)) {
                LOG_WRN("spurious event");
                return;
        }

        status = light_on(cfg->light);
        if (status != 0) {
                bofp1_finish(dev, status);
                return;
        }

        k_work_reschedule(&data->light_wait_work, LIGHT_TIMEOUT);

        LOG_INF("dc calibration done");
}

static void bofp1_light_ready(struct rtio_iodev_sqe *iodev_sqe)
{
        int status;
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        const struct device *dev = config->sensor;
        struct bofp1_data *data = dev->data;
        struct rtio_sqe *sqe;
        uint8_t reg[2];

        if (atomic_test_bit(&data->state, BOFP1_DC_CALIB)) {
                reg[0] = BOFP1_WRITE_REG(BOFP1_REG_DC_CALIB);

                LOG_INF("begin dc calibration");
        } else {
                reg[0] = BOFP1_WRITE_REG(BOFP1_REG_SAMPLE);

                LOG_INF("begin sampling");
        }

        status = bofp1_enable_read(dev);
        if (status != 0) {
                bofp1_finish(dev, status);
                return;
        }

        atomic_set_bit(&data->state, BOFP1_BUSY);

        sqe = rtio_sqe_acquire(data->rtio_ctx);
        __ASSERT_NO_MSG(sqe != NULL);

        reg[1] = 0;
        rtio_sqe_prep_tiny_write(sqe, data->iodev_bus, RTIO_PRIO_NORM, reg,
                                 sizeof(reg), NULL);
        rtio_submit(data->rtio_ctx, 0);
}

static void bofp1_light_ready_work(struct k_work *work)
{
        struct k_work_delayable *dwork = k_work_delayable_from_work(work);
        struct bofp1_data *data =
                CONTAINER_OF(dwork, struct bofp1_data, light_wait_work);

        struct rtio_work_req *req = rtio_work_req_alloc();
        __ASSERT_NO_MSG(req != NULL);

        rtio_work_req_submit(req, data->iodev_sqe, bofp1_light_ready);
}

static void bofp1_submit_fetch(struct rtio_iodev_sqe *iodev_sqe)
{
        int status;
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        const struct device *dev = config->sensor;
        struct bofp1_data *data = dev->data;
        const struct bofp1_cfg *cfg = dev->config;
        size_t req_len;
        size_t real_len;
        struct bofp1_rtio_header header;
        struct rtio_sqe *sqe;
        uint8_t flush_reg[2];

        status = light_off(cfg->light);
        if (status != 0) {
                goto error;
        }

        header.frames = bofp1_frame_size(dev) / 2;
        req_len = sizeof(header) + bofp1_frame_size(dev);

        status = rtio_sqe_rx_buf(iodev_sqe, req_len, req_len, &data->wr_buf,
                                 &real_len);
        if (status != 0) {
                goto error;
        }

        (void)memcpy(data->wr_buf, &header, sizeof(header));

        atomic_set(&data->status, 0);
        atomic_set_bit(&data->state, BOFP1_DC_CALIB);

        data->iodev_sqe = iodev_sqe;
        data->wr_index = 0;

        sqe = rtio_sqe_acquire(data->rtio_ctx);
        __ASSERT_NO_MSG(sqe != NULL);

        flush_reg[0] = BOFP1_WRITE_REG(BOFP1_REG_FLUSH);
        flush_reg[1] = 0;

        rtio_sqe_prep_tiny_write(sqe, data->iodev_bus, RTIO_PRIO_HIGH,
                                 flush_reg, sizeof(flush_reg), NULL);

        rtio_submit(data->rtio_ctx, 0);

        /* The light timeout is more than enough to flush */
        k_work_reschedule(&data->light_wait_work, LIGHT_TIMEOUT);

        return;

error:
        bofp1_finish(dev, status);
}

static void bofp1_finish(const struct device *dev, int status)
{
        struct bofp1_data *data = dev->data;
        struct rtio_iodev_sqe *sqe = data->iodev_sqe;
        const struct bofp1_cfg *cfg = dev->config;

        data->iodev_sqe = NULL;
        data->wr_buf = NULL;

        if (status == 0) {
                rtio_iodev_sqe_ok(sqe, 0);
        } else {
                rtio_iodev_sqe_err(sqe, status);
        }

        (void)light_off(cfg->light);
        atomic_clear_bit(&data->state, BOFP1_BUSY);
        k_sem_give(&data->lock);

        LOG_INF("done");
}

static void bofp1_rtio_finish(struct rtio *r, const struct rtio_sqe *sqe,
                              void *dev_arg)
{
        ARG_UNUSED(r);
        ARG_UNUSED(sqe);

        const struct device *dev = dev_arg;
        struct bofp1_data *data = dev->data;

        if (data->status_raw != 0) {
                LOG_WRN("read produced errors: 0x%x",
                        (uint32_t)data->status_raw);
        }

        bofp1_finish(dev_arg, atomic_get(&data->status));
}

/** @brief Reset and reconfigure using RTIO methods */
static void bofp1_rtio_err(struct rtio *r, const struct rtio_sqe *sqe,
                           void *dev_arg)
{
        ARG_UNUSED(sqe);

        uint8_t reg_reset[2];
        uint8_t reg_conf_sh[6];
        uint8_t reg_conf_cap[4];
        const struct device *dev = dev_arg;
        struct bofp1_data *data = dev->data;
        struct rtio_sqe *reset;
        struct rtio_sqe *conf_sh;
        struct rtio_sqe *conf_cap;
        struct rtio_sqe *finish;

        reset = rtio_sqe_acquire(data->rtio_ctx);
        conf_sh = rtio_sqe_acquire(data->rtio_ctx);
        conf_cap = rtio_sqe_acquire(data->rtio_ctx);
        finish = rtio_sqe_acquire(data->rtio_ctx);

        LOG_INF("resetting FPGA");

        /* The FPGA can handle two consecutive commands, but it requires
         * some clock cycles to perform the reset and we should therefore split
         * the transaction into two. The delay on the MCU between these two
         * packets will be more than enough. */
        reg_reset[0] = BOFP1_WRITE_REG(BOFP1_REG_RESET); /* Reset */
        reg_reset[1] = 0;

        /* Tiny writes are hard-coded capped at 7 bytes, so the
         * transaction for configuration needs to be split into two
         * transactions. */
        reg_conf_sh[0] = BOFP1_WRITE_REG(BOFP1_REG_CCD_SH1); /* Set SH div */
        reg_conf_sh[1] = data->shdiv[0];
        reg_conf_sh[2] = BOFP1_WRITE_REG(BOFP1_REG_CCD_SH2); /* Set SH div */
        reg_conf_sh[3] = data->shdiv[1];
        reg_conf_sh[4] = BOFP1_WRITE_REG(BOFP1_REG_CCD_SH3); /* Set SH div */
        reg_conf_sh[5] = data->shdiv[2];

        /* Configure pipeline-specific registers */
        reg_conf_cap[0] = BOFP1_WRITE_REG(BOFP1_REG_MOVING_AVG_N);
        reg_conf_cap[1] = data->moving_avg_n;
        reg_conf_cap[2] = BOFP1_WRITE_REG(BOFP1_REG_TOTAL_AVG_N);
        reg_conf_cap[3] = data->total_avg_n;

        rtio_sqe_prep_tiny_write(reset, data->iodev_bus, RTIO_PRIO_NORM,
                                 reg_reset, sizeof(reg_reset), NULL);
        rtio_sqe_prep_tiny_write(conf_sh, data->iodev_bus, RTIO_PRIO_NORM,
                                 reg_conf_sh, sizeof(reg_conf_sh), NULL);
        rtio_sqe_prep_tiny_write(conf_cap, data->iodev_bus, RTIO_PRIO_NORM,
                                 reg_conf_cap, sizeof(reg_conf_cap), NULL);

        reset->flags = RTIO_SQE_CHAINED;
        conf_sh->flags = RTIO_SQE_CHAINED;
        conf_cap->flags = RTIO_SQE_CHAINED;

        rtio_sqe_prep_callback(finish, bofp1_rtio_finish, (void *)dev, NULL);

        rtio_submit(data->rtio_ctx, 0);
}

static void bofp1_rtio_continue(struct rtio *r, const struct rtio_sqe *sqe,
                                void *dev_arg)
{
        ARG_UNUSED(r);
        ARG_UNUSED(sqe);

        if (!bofp1_gpio_check(dev_arg)) {
                bofp1_enable_read(dev_arg);
        }
}

static void bofp1_data_read(const struct device *dev)
{
        struct bofp1_data *data = dev->data;
        size_t size;
        size_t index;
        uint8_t reg[2];
        uint8_t status_reg;
        struct rtio_sqe *wr_reg;
        struct rtio_sqe *wr_status;
        struct rtio_sqe *rd_status;
        struct rtio_sqe *rd_data;
        struct rtio_sqe *cb_action;

        index = data->wr_index;
        if (index >= bofp1_frame_size(dev)) {
                LOG_WRN("duplicate read detected");
                return;
        }

        size = bofp1_frame_size(dev) - index;
        if (size > READ_CHUNK_SIZE) {
                size = READ_CHUNK_SIZE;

                if (!atomic_test_bit(&data->state, BOFP1_BUSY)) {
                        LOG_ERR("sensor completed while data is still in fifo");
                        cb_action = rtio_sqe_acquire(data->rtio_ctx);

                        bofp1_set_status(dev, -EBUSY);
                        rtio_sqe_prep_callback(cb_action, bofp1_rtio_err,
                                               (void *)dev, NULL);
                        rtio_submit(data->rtio_ctx, 0);
                        return;
                }
        }

        LOG_INF("index: %zu, size: %zu", index, size);

        wr_reg = rtio_sqe_acquire(data->rtio_ctx);
        rd_data = rtio_sqe_acquire(data->rtio_ctx);
        wr_status = rtio_sqe_acquire(data->rtio_ctx);
        rd_status = rtio_sqe_acquire(data->rtio_ctx);
        cb_action = rtio_sqe_acquire(data->rtio_ctx);

        if (wr_reg == NULL || rd_data == NULL || cb_action == NULL ||
            wr_status == NULL || rd_status == NULL) {
                bofp1_finish(dev, -ENOMEM);
                return;
        }

        /* Read stream data */
        reg[0] = BOFP1_READ_REG(BOFP1_REG_STREAM);
        reg[1] = 0;
        rtio_sqe_prep_tiny_write(wr_reg, data->iodev_bus, RTIO_PRIO_HIGH, reg,
                                 sizeof(reg), NULL);
        rtio_sqe_prep_read(rd_data, data->iodev_bus, RTIO_PRIO_HIGH,
                           data->wr_buf + sizeof(struct bofp1_rtio_header) +
                                   index,
                           size, NULL);

        wr_reg->flags = RTIO_SQE_TRANSACTION;
        rd_data->flags = RTIO_SQE_CHAINED;

        /* Read status flag */
        status_reg = BOFP1_READ_REG(BOFP1_REG_STATUS);
        rtio_sqe_prep_tiny_write(wr_status, data->iodev_bus, RTIO_PRIO_HIGH,
                                 &status_reg, sizeof(status_reg), NULL);
        rtio_sqe_prep_read(rd_status, data->iodev_bus, RTIO_PRIO_HIGH,
                           &data->status_raw, sizeof(data->status_raw), NULL);

        wr_status->flags = RTIO_SQE_TRANSACTION;
        rd_status->flags = RTIO_SQE_CHAINED;

        data->wr_index += size;
        if (data->wr_index >= bofp1_frame_size(dev)) {
                /* Finish up */
                rtio_sqe_prep_callback(cb_action, bofp1_rtio_finish,
                                       (void *)dev, NULL);
        } else {
                /* Re-enable read */
                rtio_sqe_prep_callback(cb_action, bofp1_rtio_continue,
                                       (void *)dev, NULL);
        }

        rtio_submit(data->rtio_ctx, 0);
}

static void bofp1_data_read_work(struct rtio_iodev_sqe *iodev_sqe)
{
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        const struct device *dev = config->sensor;

        bofp1_data_read(dev);
}

static void bofp1_abort_work(struct rtio_iodev_sqe *iodev_sqe)
{
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        const struct device *dev = config->sensor;
        struct bofp1_data *data = dev->data;

        LOG_ERR("timed out");

        bofp1_set_status(dev, -ETIMEDOUT);
        bofp1_rtio_err(data->rtio_ctx, NULL, (void *)dev);
}

void bofp1_submit(const struct device *dev, struct rtio_iodev_sqe *iodev_sqe)
{
        struct rtio_work_req *work;
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        struct bofp1_data *data = dev->data;

        __ASSERT(!config->is_streaming, "streaming not supported");

        /* Lock must be held for the entire transmission */
        (void)k_sem_take(&data->lock, K_FOREVER);

        work = rtio_work_req_alloc();
        rtio_work_req_submit(work, iodev_sqe, bofp1_submit_fetch);
}

void bofp1_rtio_read(const struct device *dev)
{
        int status;
        struct bofp1_data *data = dev->data;
        struct rtio_work_req *req = rtio_work_req_alloc();

        status = bofp1_disable_read(dev);
        __ASSERT_NO_MSG(status == 0);

        rtio_work_req_submit(req, data->iodev_sqe, bofp1_data_read_work);
}

void bofp1_rtio_complete(const struct device *dev)
{
        int status;
        struct bofp1_data *data = dev->data;
        struct rtio_work_req *req = rtio_work_req_alloc();

        status = bofp1_disable_read(dev);
        __ASSERT_NO_MSG(status == 0);

        if (atomic_test_bit(&data->state, BOFP1_DC_CALIB)) {
                rtio_work_req_submit(req, data->iodev_sqe, bofp1_dc_calib_done);
        } else {
                rtio_work_req_submit(req, data->iodev_sqe,
                                     bofp1_data_read_work);
        }
}

void bofp1_rtio_watchdog(struct k_work *work)
{
        int status;
        struct rtio_work_req *req;
        struct k_work_delayable *dwork = k_work_delayable_from_work(work);
        struct bofp1_data *data =
                CONTAINER_OF(dwork, struct bofp1_data, watchdog_work);

        status = bofp1_disable_read(data->dev);
        __ASSERT_NO_MSG(status == 0);

        atomic_clear_bit(&data->state, BOFP1_BUSY);

        req = rtio_work_req_alloc();
        rtio_work_req_submit(req, data->iodev_sqe, bofp1_abort_work);
}

int bofp1_rtio_init(const struct device *dev)
{
        struct bofp1_data *data = dev->data;

        k_work_init_delayable(&data->light_wait_work, bofp1_light_ready_work);
        k_work_init_delayable(&data->watchdog_work, bofp1_rtio_watchdog);

        return 0;
}
