
#include <stdio.h>
#include <zephyr/kernel.h>

int main(void)
{
        for (;;) {
                (void)printf("Hello World\n");

                k_sleep(K_MSEC(1000));
        }

        return 0;
}
