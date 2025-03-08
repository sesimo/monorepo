
#include <zephyr/usb/usbd.h>
#include <zephyr/usb/usb_ch9.h>
#include <zephyr/usb/class/usb_cdc.h>

#include <zephyr/drivers/usb/udc.h>

#include "common.h"

USBD_DESC_LANG_DEFINE(bomc1_usb_lang);
USBD_DESC_MANUFACTURER_DEFINE(bomc1_usb_manufacturer, SSM_VENDOR_NAME);
USBD_DESC_PRODUCT_DEFINE(bomc1_usb_product, SSM_BOMC1_PRODUCT_NAME);

USBD_DESC_CONFIG_DEFINE(bomc1_usb_fs_conf_str, "FS configuration");
USBD_CONFIGURATION_DEFINE(bomc1_usb_fs_conf, 0, 125, &bomc1_usb_fs_conf_str);

USBD_DEVICE_DEFINE(bomc1_usb, DEVICE_DT_GET(DT_NODELABEL(zephyr_udc0)), SSM_VID,
                   SSM_BOMC1_PID);

int bomc1_usb_init(void)
{
        int status;

        status = usbd_add_configuration(&bomc1_usb, USBD_SPEED_FS,
                                        &bomc1_usb_fs_conf);
        if (status != 0) {
                return status;
        }

        status = usbd_add_descriptor(&bomc1_usb, &bomc1_usb_lang);
        if (status != 0) {
                return status;
        }

        status = usbd_add_descriptor(&bomc1_usb, &bomc1_usb_manufacturer);
        if (status != 0) {
                return status;
        }
        status = usbd_add_descriptor(&bomc1_usb, &bomc1_usb_product);
        if (status != 0) {
                return status;
        }

        status = usbd_register_all_classes(&bomc1_usb, USBD_SPEED_FS, 1, NULL);
        if (status != 0) {
                return status;
        }

        status = usbd_init(&bomc1_usb);
        if (status != 0) {
                return status;
        }

        status = usbd_enable(&bomc1_usb);
        if (status != 0) {
                return status;
        }

        return 0;
}
