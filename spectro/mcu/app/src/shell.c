
#include <zephyr/shell/shell.h>
#include <zephyr/drivers/sensor.h>

SENSOR_DT_READ_IODEV(ccd_iodev, DT_NODELABEL(bofp1));
RTIO_DEFINE(rtio_ctx, 1, 1);

static uint8_t buf[4096];

static int cmd_ccd_sample(const struct shell *sh, size_t argc, char **argv)
{
        ARG_UNUSED(argc);
        ARG_UNUSED(argv);

        shell_print(sh, "Sampling CCD");

        return sensor_read(&ccd_iodev, &rtio_ctx, buf, sizeof(buf));
}

SHELL_STATIC_SUBCMD_SET_CREATE(ccd_shell,
                               SHELL_CMD(sample, NULL, "Execute a sample",
                                         cmd_ccd_sample),
                               SHELL_SUBCMD_SET_END);

SHELL_CMD_REGISTER(ccd, &ccd_shell, "CCD commands", NULL);
