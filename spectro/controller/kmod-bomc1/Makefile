
PWD := $(CURDIR)

SRC := $(PWD)/src
BUILD := $(PWD)/build

UNAME := $(shell uname -r)
MAKE_DIR := /lib/modules/$(UNAME)/build
MAKE_CMD := $(MAKE) -C $(MAKE_DIR) M=$(BUILD)

# Populated by subdirectory makefiles
SOURCES =

include $(SRC)/Makefile

obj-m += $(patsubst %.c,%.o,$(SOURCES))

prepare_builddir=rsync -a --exclude=$(BUILD) $(PWD)/* $(BUILD)

all:
	@$(prepare_builddir)
	@cd $(BUILD)
	@$(MAKE_CMD) modules

clean:
	@$(MAKE_CMD) clean
	@rm -rf $(BUILD)
