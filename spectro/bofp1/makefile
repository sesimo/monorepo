
TARGET?=
OPTS?="--wave=wave.ghw"
GHDL?=ghdl-mcode

SOURCES=\
	platform/uvvm/clk_wizard.vhd \
	platform/uvvm/fifo_common.vhd \
	platform/uvvm/fifo_data.vhd \
	platform/uvvm/fifo_ctrl.vhd \
	src/util/utils_pkg.vhd  \
	src/util/counter.vhd  \
	src/util/enable.vhd   \
	src/util/pulse.vhd   \
	src/util/edge.vhd \
	src/reset.vhd  \
	src/spi/spi_common.vhd \
	src/spi/spi_main.vhd \
	src/spi/spi_sub.vhd  \
	src/adc.vhd  \
	src/ccd.vhd  \
	src/capture.vhd \
	src/ctrl/ctrl_common_pkg.vhd \
	src/ctrl/ctrl.vhd \
	src/bofp1.vhd

GHDL_ARGS=--workdir=$(realpath build) --std=08 -frelaxed-rules \
		  -P$(shell pwd)/build/ghdl -g
GHDL_RUNARGS=--assert-level=warning

target_name=$(shell basename $(1) | cut -d"." -f1)

all: build/tb_adc.o

build/%.o: $(SOURCES) tests/%.vhd
	echo $(SOURCES)
	$(GHDL) -a $(GHDL_ARGS) $^
	@cd build && $(GHDL) -e $(GHDL_ARGS) $(call target_name, $@)

run: $(TARGET)
	@cd build && $(GHDL) -r $(GHDL_ARGS) $(call target_name, $^) $(GHDL_RUNARGS) $(OPTS)

view_wave: build/wave.ghw
	gtkwave $^

.PHONY: clean
clean:
	rm -rf build/*
