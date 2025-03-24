
#ifndef BOMC1_DRV_IIO_H__
#define BOMC1_DRV_IIO_H__

#include <linux/iio/iio.h>
#include <linux/usb.h>

#define BOMC1_IIO_DEV_NAME "bomc1-spectrometer"

struct bomc1_iio_data {
        struct iio_dev *iiodev;
        struct usb_interface *usb_intf;
};

int bomc1_iio_setup(struct bomc1_iio_data *data,
                    struct usb_interface *usb_intf);

void bomc1_iio_destroy(struct bomc1_iio_data *data,
                       struct usb_interface *usb_intf);

#endif /* BOMC1_DRV_IIO_H__ */
