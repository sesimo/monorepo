
PWD := $(CURDIR)

UNAME := $(shell uname -r)
MAKE_DIR := /lib/modules/$(UNAME)/build
MAKE_CMD := $(MAKE) -C $(MAKE_DIR) M=$(PWD)

obj-m += drivers/iio/light/bomc1.o

all:
	$(MAKE_CMD) modules

clean:
	@$(MAKE_CMD) clean
