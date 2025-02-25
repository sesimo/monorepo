
#ifndef SESIMO_BOFP1_H__
#define SESIMO_BOFP1_H__

#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/spi.h>

#define BOFP1_REG_OFFSET (4)
#define BOFP1_REG_BIT_WR (1 << 7)

#define BOFP1_REG_STREAM   (0x0) /* Stream for entirety of transmission */
#define BOFP1_REG_SAMPLE   (0x1) /* Begin sample. Write only */
#define BOFP1_REG_PSC      (0x2) /* Prescaler */
#define BOFP1_REG_CCD_MCLK (0x3) /* CCD master clock frequency (clock div) */
#define BOFP1_REG_CCD_SH   (0x4) /* Shutter frequncy (clock div)  */

struct bofp1_cfg {
        uint8_t psc;
        uint32_t clock_frequency;

        struct spi_dt_spec bus;
};

struct bofp1_data {
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
