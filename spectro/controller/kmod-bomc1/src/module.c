
#include <linux/module.h>
#include <linux/init.h>

#include "module.h"

static int __init bomc1_init(void)
{
        pr_info("BOCM1 loaded");
        return 0;
}

static void __exit bomc1_exit(void)
{
}

module_init(bomc1_init);
module_exit(bomc1_exit);

MODULE_AUTHOR(SSM_MOD_AUTHOR);
MODULE_LICENSE(SSM_MOD_LICENSE);
MODULE_DESCRIPTION("SESIMO BOMC1 driver module");
