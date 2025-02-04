
#include <stdio.h>
#include <zephyr/kernel.h>

static const struct device *dev = DEVICE_DT_GET_ANY(toshiba_tcd1304);

int main(void)
{
        if (!device_is_ready(dev)) {
                (void)printf("CCD not set up\n");
        }

        for (;;) {
                (void)printf("Hello World\n");

                k_sleep(K_MSEC(1000));
        }

        return 0;
}
