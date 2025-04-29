
#ifndef SESIMO_BOFP1_H__
#define SESIMO_BOFP1_H__

#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/drivers/gpio.h>

#define BOFP1_REG_OFFSET (0)
#define BOFP1_REG_BIT_WR (1 << 7)

#define BOFP1_READ_REG(r)  (r << BOFP1_REG_OFFSET)
#define BOFP1_WRITE_REG(r) ((r << BOFP1_REG_OFFSET) | BOFP1_REG_BIT_WR)

/* Stream pipeline data for entirety of transmission */
#define BOFP1_REG_STREAM       (0x1)
#define BOFP1_REG_SAMPLE       (0x2) /* Begin sample. Write only */
#define BOFP1_REG_RESET        (0x3) /* Reset */
#define BOFP1_REG_CCD_SH1      (0x4) /* 24bit SH freq (clock div) MSB byte 0 */
#define BOFP1_REG_CCD_SH2      (0x5) /* 24bit SH freq (clock div) MSB byte 1 */
#define BOFP1_REG_CCD_SH3      (0x6) /* 24bit SH freq (clock div) MSB byte 2 */
#define BOFP1_REG_PRCCTRL      (0x7) /* Processing control register */
#define BOFP1_REG_MOVING_AVG_N (0x8) /* Number of neighbours for moving avg */
#define BOFP1_REG_TOTAL_AVG_N  (0x9) /* Number of frames for total average */
#define BOFP1_REG_STATUS       (0xa) /* Status register */
#define BOFP1_REG_DC_CALIB     (0xb) /* Trigger DC calibration*/

#define BOFP1_PRC_WMARK_SRC  (0x0)
#define BOFP1_PRC_BUSY_SRC   (0x1)
#define BOFP1_PRC_TOTAVG_ENA (0x2)
#define BOFP1_PRC_MOVAVG_ENA (0x3)
#define BOFP1_PRC_DC_ENA     (0x4)

#define BOFP1_NUM_ELEMENTS (3648)

#define BOFP1_BUSY     (0) /* Sensor busy */
#define BOFP1_DC_CALIB (1) /* In DC calib */

struct bofp1_cfg {
        uint8_t clkdiv;
        uint32_t integration_time_dt;
        uint32_t clock_frequency;
        uint8_t moving_avg_n_dt;
        uint8_t total_avg_n_dt;
        bool totavg_dt;
        bool dc_dt;
        bool movavg_dt;

        struct spi_dt_spec bus;
        struct gpio_dt_spec busy_gpios;
        struct gpio_dt_spec fifo_w_gpios;

        const struct device* light;
};

struct bofp1_data {
        uint8_t shdiv[3];
        uint8_t total_avg_n;
        uint8_t moving_avg_n;

        uint8_t prc;

        /* Status on FPGA */
        uint8_t status_raw;

        struct gpio_callback busy_fall_cb;
        struct gpio_callback fifo_w_cb;

        /* Reference to self so that the callbacks can get the device from the
         * data struct. */
        const struct device *dev;

        struct rtio_iodev_sqe *iodev_sqe;
        struct rtio *rtio_ctx;

        struct rtio_iodev *iodev_bus;

        uint8_t *wr_buf;
        size_t wr_index;

        struct k_spinlock lock;

        struct k_work_delayable watchdog_work;
        struct k_work_delayable light_wait_work;

        atomic_t state;
        atomic_t status;
};

struct bofp1_rtio_header {
        size_t frames;
};

int bofp1_rtio_init(const struct device *dev);

int bofp1_access(const struct device *dev, bool write, uint8_t addr, void *data,
                 size_t size);

int bofp1_write_reg(const struct device *dev, uint8_t addr, uint8_t value);

int bofp1_stream(const struct device *dev, void *data, size_t size);

int bofp1_read_reg(const struct device *dev, uint8_t addr, uint8_t *value);

uint8_t bofp1_get_prc(const struct device *dev, unsigned int bit);

void bofp1_submit(const struct device *dev, struct rtio_iodev_sqe *sqe);

int bofp1_get_decoder(const struct device *dev,
                      const struct sensor_decoder_api **decoder);

bool bofp1_gpio_check(const struct device *dev);

void bofp1_rtio_read(const struct device *dev);

void bofp1_rtio_complete(const struct device *dev);

void bofp1_rtio_watchdog(struct k_work *work);

int bofp1_enable_read(const struct device *dev);

int bofp1_disable_read(const struct device *dev);

#endif /* SESIMO_BOFP1_H__ */
