
#include <linux/module.h>
#include <linux/init.h>
#include <linux/usb.h>

#include "module.h"

static const struct usb_device_id bomc1_id_table[] = {
        {USB_DEVICE(0xf005, 0x001)},
        {/* sentinel */},
};

MODULE_DEVICE_TABLE(usb, bomc1_id_table);

static int bomc1_probe(struct usb_interface *intf,
                       const struct usb_device_id *id)
{
        pr_info("Probed");
        return 0;
}

static void bomc1_disconnect(struct usb_interface *intf)
{
        pr_info("Disconnect");
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
