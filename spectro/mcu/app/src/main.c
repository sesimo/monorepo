
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "usb/usb.h"

LOG_MODULE_REGISTER(app);

int main(void)
{
        int status;

        status = bomc1_usb_init();
        if (status != 0) {
                LOG_ERR("usb init failed: %i", status);
                return status;
        }

        return 0;
};
