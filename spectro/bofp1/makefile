
TARGET?=
OPTS?="--wave=wave.ghw"
GHDL?=ghdl-mcode

SOURCES=src/util/dff.vhd      \
		src/util/cdc_vector.vhd \
		src/util/counter.vhd  \
		src/util/enable.vhd   \
		src/afifo.vhd \
		src/adc.vhd  \
		src/pwm.vhd  \
		src/ccd.vhd  \
		src/spi/spi_main.vhd \
		src/spi/spi_sub.vhd  \
		src/ctrl.vhd

GHDL_ARGS=--workdir=$(realpath build) --std=08 -frelaxed-rules \
		  -P$(shell pwd)/build/ghdl
GHDL_RUNARGS=--assert-level=failure

target_name=$(shell basename $(1) | cut -d"." -f1)

all: build/tb_adc.o

build/%.o: $(SOURCES) tests/%.vhd
	$(GHDL) -a $(GHDL_ARGS) $^
	@cd build && $(GHDL) -e $(GHDL_ARGS) $(call target_name, $@)

run: $(TARGET)
	@cd build && $(GHDL) -r $(GHDL_ARGS) $(call target_name, $^) $(GHDL_RUNARGS) $(OPTS)

view_wave: build/wave.ghw
	gtkwave $^

.PHONY: clean
clean:
	rm -rf build/*
