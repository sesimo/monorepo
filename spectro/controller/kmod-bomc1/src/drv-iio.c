
#include <linux/module.h>
#include <linux/init.h>
#include <linux/iio/triggered_buffer.h>
#include <linux/iio/trigger_consumer.h>
#include <linux/usb.h>

#include "module.h"
#include "drv-iio.h"

#define BOMC1_SPECTRO_READ (0x01)

#define BOMC1_EP_BULK (0x1)

#define BOMC1_TIMEOUT_MS (100)

#define BOMC1_FRAME_LEN  (3648)
#define BOMC1_FRAME_SIZE (BOMC1_FRAME_LEN * sizeof(u16))

struct bomc1_iio_ctx {
        struct bomc1_iio_data *data;
        struct mutex lock;
};

static const struct iio_chan_spec bomc1_iio_channels[] = {
        {
                .type = IIO_VOLTAGE,
                .scan_type =
                        {
                                .endianness = IIO_BE,
                                .realbits = 16,
                        },
        },
};

/** @brief Issue a spectro read request to the control endpoint */
static int bomc1_iio_begin_read(struct bomc1_iio_ctx *ctx)
{
        int status;
        struct bomc1_iio_data *data = ctx->data;
        struct usb_device *udev = interface_to_usbdev(data->usb_intf);

        status = usb_control_msg_send(udev, 0, BOMC1_SPECTRO_READ,
                                      USB_TYPE_VENDOR, 0, 0, NULL, 0,
                                      USB_CTRL_SET_TIMEOUT, GFP_KERNEL);
        if (status != 0) {
                return status;
        }

        return 0;
}

/** @brief Read out one frame from the spectrometer */
static int bomc1_iio_read_frame(struct bomc1_iio_ctx *ctx, u8 *recv_buf)
{
        int status;
        int pipe;
        int len;
        struct usb_interface *usb_intf = ctx->data->usb_intf;
        struct usb_device *udev = interface_to_usbdev(usb_intf);

        status = bomc1_iio_begin_read(ctx);
        if (status != 0) {
                return status;
        }

        pipe = usb_rcvbulkpipe(udev, BOMC1_EP_BULK);

        status = usb_bulk_msg(udev, pipe, recv_buf, BOMC1_FRAME_SIZE, &len,
                              BOMC1_TIMEOUT_MS);
        if (status != 0 || len != BOMC1_FRAME_SIZE) {
                dev_err(&usb_intf->dev, "Incomplete read: status %i, %i bytes",
                        status, len);
        }

        return status;
}

static int bomc1_iio_read_raw(struct iio_dev *iiodev,
                              const struct iio_chan_spec *chan, int *val,
                              int *val2, long mask)
{
        switch (mask) {
        case IIO_CHAN_INFO_SCALE:
                switch (chan->type) {
                case IIO_VOLTAGE:
                        break;
                default:
                        return -EINVAL;
                }

                break;
        default:
                return -EINVAL;
        }

        return 0;
}

static struct attribute *bomc1_iio_attrs[] = {
        NULL,
};

static const struct attribute_group bomc1_iio_attr_group = {
        .attrs = bomc1_iio_attrs,
};

static const struct iio_info bomc1_iio_info = {
        .read_raw = bomc1_iio_read_raw,
        .attrs = &bomc1_iio_attr_group,
};

/**
 * @brief Read out a frame from the spectrometer
 *
 * This function is invoked in the context of a kernel thread and can
 * safely block.
 */
static irqreturn_t bomc1_iio_trigger_handler(int irq, void *p)
{
        u8 *recv_buf;
        int status;
        struct iio_poll_func *pf = p;
        struct iio_dev *iiodev = pf->indio_dev;
        struct bomc1_iio_ctx *ctx = iio_priv(iiodev);
        struct usb_interface *usb_intf = ctx->data->usb_intf;

        mutex_lock(&ctx->lock);

        recv_buf = kmalloc(BOMC1_FRAME_SIZE, GFP_KERNEL);
        if (recv_buf == NULL) {
                dev_err(&usb_intf->dev, "Unable to allocate receive buffer");
                status = -ENOMEM;
                goto exit;
        }

        status = bomc1_iio_read_frame(ctx, recv_buf);
        if (status != 0) {
                goto exit;
        }

exit:
        mutex_unlock(&ctx->lock);

        if (status == 0) {
                iio_push_to_buffers(iiodev, recv_buf);
                iio_trigger_notify_done(iiodev->trig);
        }

        if (recv_buf != NULL) {
                kfree(recv_buf);
        }

        return IRQ_HANDLED;
}

int bomc1_iio_setup(struct bomc1_iio_data *data, struct usb_interface *usb_intf)
{
        int status;
        struct bomc1_iio_ctx *ctx;

        data->usb_intf = usb_intf;

        data->iiodev = devm_iio_device_alloc(&usb_intf->dev, sizeof(*ctx));
        if (data->iiodev == NULL) {
                dev_err(&usb_intf->dev, "IIO device allocation failed");
                return -ENOMEM;
        }

        ctx = iio_priv(data->iiodev);
        ctx->data = data;
        mutex_init(&ctx->lock);

        data->iiodev->name = BOMC1_IIO_DEV_NAME;
        data->iiodev->info = &bomc1_iio_info;
        data->iiodev->modes = INDIO_BUFFER_TRIGGERED;
        data->iiodev->channels = bomc1_iio_channels;
        data->iiodev->num_channels = ARRAY_SIZE(bomc1_iio_channels);

        status = devm_iio_triggered_buffer_setup(
                &usb_intf->dev, data->iiodev, NULL, bomc1_iio_trigger_handler,
                NULL);
        if (status != 0) {
                dev_err(&usb_intf->dev, "Unable to setup buffer: %i", status);
                return status;
        }

        return devm_iio_device_register(&usb_intf->dev, data->iiodev);
}
EXPORT_SYMBOL(bomc1_iio_setup);

/* The IIO drivers is attached to the USB driver, and will detach itself
 * automatically when the USB driver is detached. We therefore dont need
 * to do anything here. */
void bomc1_iio_destroy(struct bomc1_iio_data *data,
                       struct usb_interface *usb_intf)
{
        (void)data;
        (void)usb_intf;
}
EXPORT_SYMBOL(bomc1_iio_destroy);

MODULE_LICENSE(SSM_MOD_LICENSE);
