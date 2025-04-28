
#include <zephyr/rtio/rtio.h>
#include <zephyr/rtio/work.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/sensor.h>

#include "bofp1.h"

LOG_MODULE_DECLARE(sesimo_bofp1);

#define READ_CHUNK_SIZE (256 * sizeof(uint16_t))

static inline size_t bofp1_frame_size(const struct device *dev)
{
        struct bofp1_data *data = dev->data;
        size_t ret;

        ret = BOFP1_NUM_ELEMENTS_TOTAL;
        if (bofp1_get_prc(dev, BOFP1_PRC_MOVAVG_ENA)) {
                ret -= data->moving_avg_n * 2;
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

static void bofp1_submit_fetch(struct rtio_iodev_sqe *iodev_sqe)
{
        int status;
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        const struct device *dev = config->sensor;
        struct bofp1_data *data = dev->data;
        struct rtio_sqe *sqe;
        uint8_t reg[2];
        size_t real_len;

        if (atomic_test_and_set_bit(&data->state, BOFP1_BUSY)) {
                LOG_ERR("ccd busy");
                rtio_iodev_sqe_err(iodev_sqe, -EBUSY);
                return;
        }

        status = bofp1_enable_read(dev);
        if (status != 0) {
                atomic_clear_bit(&data->state, BOFP1_BUSY);
                rtio_iodev_sqe_err(iodev_sqe, status);
                return;
        }

        status = rtio_sqe_rx_buf(iodev_sqe, bofp1_frame_size(dev),
                                 bofp1_frame_size(dev), &data->wr_buf,
                                 &real_len);
        if (status != 0) {
                (void)bofp1_disable_read(dev);
                atomic_clear_bit(&data->state, BOFP1_BUSY);
                rtio_iodev_sqe_err(iodev_sqe, status);
                return;
        }

        sqe = rtio_sqe_acquire(data->rtio_ctx);
        if (sqe == NULL) {
                (void)bofp1_disable_read(dev);
                atomic_clear_bit(&data->state, BOFP1_BUSY);
                rtio_iodev_sqe_err(iodev_sqe, -ENOMEM);
                return;
        }

        atomic_set(&data->status, 0);

        reg[0] = BOFP1_WRITE_REG(BOFP1_REG_SAMPLE);
        reg[1] = 0;
        rtio_sqe_prep_tiny_write(sqe, data->iodev_bus, RTIO_PRIO_NORM, reg,
                                 sizeof(reg), NULL);

        data->iodev_sqe = iodev_sqe;
        data->wr_index = 0;

        rtio_submit(data->rtio_ctx, 0);
}

static void bofp1_finish(const struct device *dev, int status)
{
        struct bofp1_data *data = dev->data;
        struct rtio_iodev_sqe *sqe = data->iodev_sqe;

        data->iodev_sqe = NULL;
        data->wr_buf = NULL;

        if (status == 0) {
                rtio_iodev_sqe_ok(sqe, 0);
        } else {
                rtio_iodev_sqe_err(sqe, status);
        }

        atomic_clear_bit(&data->state, BOFP1_BUSY);

        LOG_INF("done");
}

static void bofp1_rtio_finish(struct rtio *r, const struct rtio_sqe *sqe,
                              void *dev_arg)
{
        ARG_UNUSED(r);
        ARG_UNUSED(sqe);

        const struct device *dev = dev_arg;
        struct bofp1_data *data = dev->data;

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
        struct rtio_sqe *wr_reg;
        struct rtio_sqe *rd_data;
        struct rtio_sqe *cb_action;
        k_spinlock_key_t key;

        key = k_spin_lock(&data->lock);

        index = data->wr_index;
        if (index >= bofp1_frame_size(dev)) {
                LOG_WRN("duplicate read detected");
                goto exit;
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
                        goto exit;
                }
        }

        LOG_INF("index: %zu, size: %zu", index, size);

        wr_reg = rtio_sqe_acquire(data->rtio_ctx);
        rd_data = rtio_sqe_acquire(data->rtio_ctx);
        cb_action = rtio_sqe_acquire(data->rtio_ctx);

        if (wr_reg == NULL || rd_data == NULL || cb_action == NULL) {
                bofp1_finish(dev, -ENOMEM);
                goto exit;
        }

        reg[0] = BOFP1_READ_REG(BOFP1_REG_STREAM);
        reg[1] = 0;
        rtio_sqe_prep_tiny_write(wr_reg, data->iodev_bus, RTIO_PRIO_HIGH, reg,
                                 sizeof(reg), NULL);
        rtio_sqe_prep_read(rd_data, data->iodev_bus, RTIO_PRIO_HIGH,
                           data->wr_buf + index, size, NULL);

        wr_reg->flags = RTIO_SQE_TRANSACTION;
        rd_data->flags = RTIO_SQE_CHAINED;

        data->wr_index += size;
        if (data->wr_index >= bofp1_frame_size()) {
                /* Finish up */
                rtio_sqe_prep_callback(cb_action, bofp1_rtio_finish,
                                       (void *)dev, NULL);
        } else {
                /* Re-enable read */
                rtio_sqe_prep_callback(cb_action, bofp1_rtio_continue,
                                       (void *)dev, NULL);
        }

        rtio_submit(data->rtio_ctx, 0);

exit:
        k_spin_unlock(&data->lock, key);
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

        __ASSERT(!config->is_streaming, "streaming not supported");

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
