
#include <zephyr/rtio/work.h>
#include <zephyr/drivers/sensor.h>

#include "bofp1.h"

static void bofp1_submit_fetch(struct rtio_iodev_sqe *iodev_sqe)
{
        int status;
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;
        const struct device *dev = config->sensor;

        status = bofp1_write_reg(dev, BOFP1_REG_SAMPLE, 0);
        if (status != 0) {
                rtio_iodev_sqe_err(iodev_sqe, status);
                return;
        }

        rtio_iodev_sqe_ok(iodev_sqe, status);
}

extern void bofp1_submit(const struct device *dev,
                         struct rtio_iodev_sqe *iodev_sqe)
{
        struct rtio_work_req *work;
        const struct sensor_read_config *config = iodev_sqe->sqe.iodev->data;

        __ASSERT(!config->is_streaming, "streaming not supported");

        work = rtio_work_req_alloc();
        rtio_work_req_submit(work, iodev_sqe, bofp1_submit_fetch);
}
