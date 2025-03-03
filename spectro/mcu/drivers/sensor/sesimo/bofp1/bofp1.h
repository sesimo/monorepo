
#ifndef SESIMO_BOFP1_H__
#define SESIMO_BOFP1_H__

#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/spi.h>

#define BOFP1_REG_OFFSET (4)
#define BOFP1_REG_BIT_WR (1 << 7)

#define BOFP1_REG_STREAM (0x0) /* Stream for entirety of transmission */
#define BOFP1_REG_SAMPLE (0x1) /* Begin sample. Write only */
#define BOFP1_REG_RESET  (0x2) /* Reset */
#define BOFP1_REG_CLKDIV (0x3) /* Prescaler */
#define BOFP1_REG_CCD_SH (0x4) /* Shutter frequncy (clock div)  */

#define BOFP1_CLKDIV_MIN   (25)
#define BOFP1_CLKDIV_MAX   (125)
#define BOFP1_CLKDIV_DERIV ((BOFP1_CLKDIV_MAX - BOFP1_CLKDIV_MIN) / 7)

#define BOFP1_DATA_CLKDIV (4) /* Data div in relation to master clock */

/* In the clockdiv register, which is packed consisting of the two below
 * values */
#define BOFP1_PSC_INDEX    (3)
#define BOFP1_CLKDIV_INDEX (0)

struct bofp1_cfg {
        uint8_t psc;
        uint8_t clkdiv_dt;
        uint32_t integration_time_dt;
        uint32_t clock_frequency;

        struct spi_dt_spec bus;
};

struct bofp1_data {
        uint8_t clkdiv;
        uint8_t shdiv;
};

int bofp1_access(const struct device *dev, bool write, uint8_t addr, void *data,
                 size_t size);

int bofp1_write_reg(const struct device *dev, uint8_t addr, uint8_t value);

int bofp1_stream(const struct device *dev, void *data, size_t size);

int bofp1_read_reg(const struct device *dev, uint8_t addr, uint8_t *value);

void bofp1_submit(const struct device *dev, struct rtio_iodev_sqe *sqe);

int bofp1_get_decoder(const struct device *dev,
                      const struct sensor_decoder_api **decoder);

#endif /* SESIMO_BOFP1_H__ */
