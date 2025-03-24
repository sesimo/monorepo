
#include <linux/module.h>
#include <linux/init.h>
#include <linux/usb.h>

#include "module.h"
#include "drv-iio.h"

static const struct usb_device_id bomc1_id_table[] = {
        {USB_DEVICE(0xf005, 0x001)},
        {/* sentinel */},
};

MODULE_DEVICE_TABLE(usb, bomc1_id_table);

struct bomc1_data {
        struct bomc1_iio_data iio;
};

static int bomc1_probe(struct usb_interface *intf,
                       const struct usb_device_id *id)
{
        int status;
        struct usb_device *dev;
        struct bomc1_data *data;

        dev = interface_to_usbdev(intf);

        data = devm_kzalloc(&intf->dev, sizeof(*data), GFP_KERNEL);
        if (data == NULL) {
                return -ENOMEM;
        }

        status = bomc1_iio_setup(&data->iio, intf);
        if (status != 0) {
                dev_err(&intf->dev, "Failed to load BOMC1 IIO: %i", status);
                goto error;
        }

        usb_set_intfdata(intf, data);

        return 0;

error:
        return status;
}

static void bomc1_disconnect(struct usb_interface *intf)
{
        struct bomc1_data *data;

        data = usb_get_intfdata(intf);

        bomc1_iio_destroy(&data->iio, intf);
        devm_kfree(&intf->dev, data);
}

static struct usb_driver bomc1_driver = {
        .name = "bomc1",
        .probe = bomc1_probe,
        .disconnect = bomc1_disconnect,
        .id_table = bomc1_id_table,
};

module_usb_driver(bomc1_driver);

MODULE_AUTHOR(SSM_MOD_AUTHOR);
MODULE_LICENSE(SSM_MOD_LICENSE);
MODULE_DESCRIPTION("SESIMO BOMC1 driver module");
