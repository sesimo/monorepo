
PWD := $(CURDIR)

SRC := $(PWD)/src
BUILD_DIR := $(PWD)/build

UNAME := $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(UNAME)/build
MAKE_CMD := $(MAKE) -C $(KERNEL_SRC) M=$(BUILD_DIR)

TARGET := $(BUILD_DIR)/bomc1.ko

prepare_builddir = \
	rsync -a \
	--exclude="$(BUILD_DIR)/" \
	$(PWD)/ $(BUILD_DIR)

all modules:
	@$(prepare_builddir)
	@$(MAKE_CMD) modules

.PHONY: insmod
insmod: modules rmmod
	modinfo $(TARGET)
	insmod $(TARGET)

.PHONY: rmmod
rmmod:
	-rmmod $(TARGET)

clean:
	@$(MAKE_CMD) clean
	@rm -rf $(BUILD_DIR)
