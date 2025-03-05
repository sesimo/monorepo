
#include <zephyr/shell/shell.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/uart.h>

SENSOR_DT_READ_IODEV(ccd_iodev, DT_NODELABEL(bofp1));
RTIO_DEFINE(rtio_ctx, 1, 1);

static uint16_t buf[4096];

static const struct device *transport =
        DEVICE_DT_GET(DT_CHOSEN(sesimo_transport));

static int cmd_ccd_sample(const struct shell *sh, size_t argc, char **argv)
{
        ARG_UNUSED(argc);
        ARG_UNUSED(argv);

        shell_print(sh, "Sampling CCD");

        return sensor_read(&ccd_iodev, &rtio_ctx, (uint8_t *)buf, sizeof(buf));
}

static int cmd_ccd_conf_set(const struct shell *sh, size_t argc, char **argv)
{
        shell_print(sh, "Count: %zu", argc);

        if (argc < 2) {
                shell_print(sh, "Usage: set <name> <value>");
                return -EINVAL;
        }

        return 0;
}

static int cmd_ccd_get(const struct shell *sh, size_t argc, char **argv)
{
        if (argc < 1) {
                shell_print(sh, "Usage: get <index>");
                return -EINVAL;
        }

        int index = atoi(argv[1]);
        shell_print(sh, "Value: %i", (int)buf[index]);

        return 0;
}

static int cmd_ccd_forward(const struct shell *sh, size_t argc, char **argv)
{
        int status;

        ARG_UNUSED(argc);
        ARG_UNUSED(argv);

        shell_print(sh, "Forwarding over USB/UART");

        status = uart_tx(transport, (uint8_t *)buf, sizeof(uint16_t) * 3694,
                         SYS_FOREVER_US);
        if (status != 0) {
                shell_print(sh, "Error forwarding: %i", status);
        }

        return status;
}

/* clang-format off */
SHELL_STATIC_SUBCMD_SET_CREATE(
        ccd_shell,
        SHELL_CMD(sample, NULL, "Execute a sample", cmd_ccd_sample),
        SHELL_CMD(set, NULL, "Set a config value", cmd_ccd_conf_set),
        SHELL_CMD(get, NULL, "Get value", cmd_ccd_get),
        SHELL_CMD(forward, NULL, "Forward reading to host", cmd_ccd_forward),
        SHELL_SUBCMD_SET_END
);
/* clang-format on */

SHELL_CMD_REGISTER(ccd, &ccd_shell, "CCD commands", NULL);
