
PWD := $(CURDIR)

UNAME := $(shell uname -r)
MAKE_DIR := /lib/modules/$(UNAME)/build
MAKE_CMD := $(MAKE) -C $(MAKE_DIR) M=$(PWD)

SRC := $(PWD)/src

include $(SRC)/Makefile

all:
	$(MAKE_CMD) modules

clean:
	@$(MAKE_CMD) clean
