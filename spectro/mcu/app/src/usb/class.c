
#include <zephyr/usb/usbd.h>
#include <zephyr/usb/usb_ch9.h>
#include <zephyr/usb/class/usb_cdc.h>

#include <zephyr/drivers/usb/udc.h>

UDC_BUF_POOL_DEFINE(udc_buf_pool_, 2, 512, sizeof(struct udc_buf_info), NULL);

struct bomc1_usb_desc {
        struct usb_association_descriptor iad;
        struct usb_if_descriptor if0;
        struct usb_ep_descriptor if0_out_ep;
        struct usb_desc_header nil_desc;
};
static const struct usb_desc_header *bomc1_usb_desc[];

static int bomc1_usbd_request(struct usbd_class_data *const c_data,
                              struct net_buf *buf, int err)
{
}

static void *bomc1_usbd_get_desc(struct usbd_class_data *const c_data,
                                 const enum usbd_speed speed)
{
        ARG_UNUSED(speed);
        ARG_UNUSED(c_data);

        return bomc1_usb_desc;
}

static int bomc1_usbd_init(struct usbd_class_data *const c_data)
{
        return 0;
}

static struct usbd_class_api bomc1_usb_api = {
        .request = bomc1_usbd_request,
        .get_desc = bomc1_usbd_get_desc,
        .init = bomc1_usbd_init,
};

static struct bomc1_usb_desc bomc1_usb_desc_s = {
        .iad =
                {
                        .bLength = sizeof(struct usb_association_descriptor),
                        .bDescriptorType = USB_DESC_INTERFACE_ASSOC,
                        .bFirstInterface = 0,
                        .bInterfaceCount = 0x01,
                        .bFunctionClass = USB_BCC_VENDOR,
                        .bFunctionSubClass = 0,
                        .bFunctionProtocol = 0,
                        .iFunction = 0,
                },
        .if0 =
                {
                        .bLength = sizeof(struct usb_if_descriptor),
                        .bDescriptorType = USB_DESC_INTERFACE,
                        .bInterfaceNumber = 0,
                        .bAlternateSetting = 0,
                        .bNumEndpoints = 3,
                        .bInterfaceClass = USB_BCC_VENDOR,
                        .bInterfaceSubClass = 0,
                        .bInterfaceProtocol = 0,
                        .iInterface = 0,
                },
        .if0_out_ep =
                {
                        .bLength = sizeof(struct usb_ep_descriptor),
                        .bDescriptorType = USB_DESC_ENDPOINT,
                        .bEndpointAddress = 0x01,
                        .bmAttributes = USB_EP_TYPE_BULK,
                        .wMaxPacketSize = sys_cpu_to_le16(64U),
                        .bInterval = 0,
                },
        .nil_desc = {/* sentinel */},
};

static const struct usb_desc_header *bomc1_usb_desc[] = {
        (struct usb_desc_header *)&bomc1_usb_desc_s.iad,
        (struct usb_desc_header *)&bomc1_usb_desc_s.if0,
        (struct usb_desc_header *)&bomc1_usb_desc_s.if0_out_ep,
        (struct usb_desc_header *)&bomc1_usb_desc_s.nil_desc,
};

struct usbd_cctx_vendor_req bomc1_usb_vendor_req = USBD_VENDOR_REQ();

USBD_DEFINE_CLASS(bomc1_usb, &bomc1_usb_api, NULL, &bomc1_usb_vendor_req);
