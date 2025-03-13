
PWD := $(CURDIR)

SRC := $(PWD)/src
BUILD_DIR := $(PWD)/build

UNAME := $(shell uname -r)
KDIR ?= /lib/modules/$(UNAME)/build
MAKE_CMD := $(MAKE) -C $(KDIR) M=$(BUILD_DIR)

prepare_builddir = \
	rsync -a \
	--exclude="$(BUILD_DIR)/" \
	$(PWD)/ $(BUILD_DIR)

all:
	@$(prepare_builddir)
	@$(MAKE_CMD) modules

clean:
	@$(MAKE_CMD) clean
	@rm -rf $(BUILD_DIR)
