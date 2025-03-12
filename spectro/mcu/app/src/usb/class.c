
#include <zephyr/usb/usbd.h>
#include <zephyr/usb/usb_ch9.h>
#include <zephyr/usb/class/usb_cdc.h>
#include <zephyr/logging/log.h>
#include <zephyr/sys/atomic.h>

#include <zephyr/drivers/usb/udc.h>

#include "../spectro.h"

LOG_MODULE_REGISTER(bomc1_usb);

#define BOMC1_VRQ_SPECTRO_READ (0x1) /* Begin CCD read */

#define BOMC1_TX_ENABLED (0)
#define BOMC1_TX_BUSY    (1)
#define BOMC1_TX_MORE    (2)

struct bomc1_usb_desc {
        struct usb_association_descriptor iad;
        struct usb_if_descriptor if0;
        struct usb_ep_descriptor if0_in_ep;
        struct usb_desc_header nil_desc;
};

struct bomc1_usb_ctx {
        struct bomc1_usb_desc *desc;
        const struct usb_desc_header **desc_list;

        atomic_t state;

        struct k_work_delayable tx_work;

        struct k_work_q workq;
        k_thread_stack_t *stack;
        size_t stack_size;

        struct usbd_class_data *c_data;
};

static void tx_handler(struct k_work *work);

static int get_bulk_in(struct usbd_class_data *const c_data)
{
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);

        return ctx->desc->if0_in_ep.bEndpointAddress;
}

static size_t get_bulk_mps(struct usbd_class_data *const c_data)
{
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);

        return sys_le16_to_cpu(ctx->desc->if0_in_ep.wMaxPacketSize);
}

static void tx_handler(struct k_work *work)
{
        int status;
        int ep;
        size_t mps;
        size_t real_size;
        struct net_buf *buf;
        struct k_work_delayable *dwork = k_work_delayable_from_work(work);
        struct bomc1_usb_ctx *ctx =
                CONTAINER_OF(dwork, struct bomc1_usb_ctx, tx_work);
        struct usbd_class_data *const c_data = ctx->c_data;

        /* Disabled */
        if (!atomic_test_bit(&ctx->state, BOMC1_TX_ENABLED)) {
                return;
        }

        if (atomic_test_and_set_bit(&ctx->state, BOMC1_TX_BUSY)) {
                return;
        }

        ep = get_bulk_in(c_data);
        mps = get_bulk_mps(c_data);

        buf = usbd_ep_buf_alloc(c_data, ep, mps);
        if (buf == NULL) {
                LOG_ERR("out of memory");

                (void)k_work_schedule_for_queue(&ctx->workq, &ctx->tx_work,
                                                K_MSEC(1));
                return;
        }

        status = spectro_stream_read(buf->data, buf->size, &real_size);
        if (status < 0) {
                LOG_ERR("read failed: %i", status);

                net_buf_unref(buf);
                return;
        }

        /* Add read size to the buffer */
        net_buf_add(buf, real_size);

        if (status > 0) {
                atomic_set_bit(&ctx->state, BOMC1_TX_MORE);
        } else {
                atomic_clear_bit(&ctx->state, BOMC1_TX_MORE);
        }

        status = usbd_ep_enqueue(c_data, buf);
        if (status != 0) {
                LOG_ERR("enqueue failed: %i", status);

                net_buf_unref(buf);
                atomic_clear_bit(&ctx->state, BOMC1_TX_MORE);
                atomic_clear_bit(&ctx->state, BOMC1_TX_BUSY);
        }
}

static void data_rdy_handler(void *user_arg)
{
        struct bomc1_usb_ctx *ctx = user_arg;

        (void)k_work_schedule_for_queue(&ctx->workq, &ctx->tx_work, K_TICKS(1));
}

static int bomc1_usbd_request(struct usbd_class_data *const c_data,
                              struct net_buf *buf, int err)
{
        int ep;
        struct udc_buf_info *bi;
        struct usbd_context *usb_ctx = usbd_class_get_ctx(c_data);
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);

        bi = udc_get_buf_info(buf);
        ep = bi->ep;

        if (err != 0) {
                if (err == -ECONNABORTED) {
                        LOG_WRN("conn aborted (ep: %i)", bi->ep);
                } else {
                        LOG_ERR("error %i (ep: %i)", err, bi->ep);
                }
        }

        if (ep == get_bulk_in(c_data)) {
                atomic_clear_bit(&ctx->state, BOMC1_TX_BUSY);

                if (atomic_test_bit(&ctx->state, BOMC1_TX_MORE)) {
                        (void)k_work_schedule_for_queue(
                                &ctx->workq, &ctx->tx_work, K_TICKS(1));
                }
        } else {
                __ASSERT(0, "unrecognized endpoint");
        }

        return usbd_ep_buf_free(usb_ctx, buf);
}

static int bomc1_usbd_cth(struct usbd_class_data *const c_data,
                          const struct usb_setup_packet *const setup,
                          struct net_buf *const buf)
{
        LOG_DBG("vendor request %" PRIu8 " (to host)", setup->bRequest);
        return -ENOTSUP;
}

static int bomc1_usbd_ctd(struct usbd_class_data *const c_data,
                          const struct usb_setup_packet *const setup,
                          const struct net_buf *const buf)
{
        int status;
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);

        LOG_DBG("vendor request %" PRIu8 " (to device)", setup->bRequest);

        switch (setup->bRequest) {
        case BOMC1_VRQ_SPECTRO_READ:
                LOG_INF("spectro begin read");

                status = spectro_sample(data_rdy_handler, ctx);
                if (status != 0) {
                        LOG_ERR("failed to read from spectrometer: %i", status);
                }

                break;
        default:
                return -ENOTSUP;
        }

        return status;
}

static void *bomc1_usbd_get_desc(struct usbd_class_data *const c_data,
                                 const enum usbd_speed speed)
{
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);
        return ctx->desc_list;
}

static void bomc1_usbd_enable(struct usbd_class_data *const c_data)
{
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);

        LOG_DBG("enable");

        atomic_set_bit(&ctx->state, BOMC1_TX_ENABLED);
}

static void bomc1_usbd_disable(struct usbd_class_data *const c_data)
{
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);

        LOG_DBG("disable");

        atomic_clear_bit(&ctx->state, BOMC1_TX_ENABLED);
}

static int bomc1_usbd_init(struct usbd_class_data *const c_data)
{
        struct bomc1_usb_ctx *ctx = usbd_class_get_private(c_data);

        ctx->c_data = c_data;

        k_work_init_delayable(&ctx->tx_work, tx_handler);
        k_work_queue_init(&ctx->workq);
        k_work_queue_start(&ctx->workq, ctx->stack, ctx->stack_size,
                           CONFIG_SYSTEM_WORKQUEUE_PRIORITY, NULL);
        k_thread_name_set(&ctx->workq.thread, "BOMC1 USBD Work queue");

        return 0;
}

static struct usbd_class_api bomc1_usb_api = {
        .enable = bomc1_usbd_enable,
        .disable = bomc1_usbd_disable,
        .request = bomc1_usbd_request,
        .control_to_dev = bomc1_usbd_ctd,
        .control_to_host = bomc1_usbd_cth,
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
                        .bNumEndpoints = 1,
                        .bInterfaceClass = USB_BCC_VENDOR,
                        .bInterfaceSubClass = 0,
                        .bInterfaceProtocol = 0,
                        .iInterface = 0,
                },
        .if0_in_ep =
                {
                        .bLength = sizeof(struct usb_ep_descriptor),
                        .bDescriptorType = USB_DESC_ENDPOINT,
                        .bEndpointAddress = 0x81,
                        .bmAttributes = USB_EP_TYPE_BULK,
                        .wMaxPacketSize = sys_cpu_to_le16(64U),
                        .bInterval = 0,
                },
        .nil_desc = {/* sentinel */},
};

static const struct usb_desc_header *bomc1_usb_desc[] = {
        (struct usb_desc_header *)&bomc1_usb_desc_s.iad,
        (struct usb_desc_header *)&bomc1_usb_desc_s.if0,
        (struct usb_desc_header *)&bomc1_usb_desc_s.if0_in_ep,
        (struct usb_desc_header *)&bomc1_usb_desc_s.nil_desc,
};

K_THREAD_STACK_DEFINE(bomc1_usb_workq_stack, 512);

static struct bomc1_usb_ctx bomc1_usb_ctx = {
        .desc = &bomc1_usb_desc_s,
        .desc_list = bomc1_usb_desc,
        .stack = bomc1_usb_workq_stack,
        .stack_size = K_THREAD_STACK_SIZEOF(bomc1_usb_workq_stack),
};

struct usbd_cctx_vendor_req bomc1_usb_vendor_req =
        USBD_VENDOR_REQ(BOMC1_VRQ_SPECTRO_READ);

USBD_DEFINE_CLASS(bomc1_usb, &bomc1_usb_api, &bomc1_usb_ctx,
                  &bomc1_usb_vendor_req);
