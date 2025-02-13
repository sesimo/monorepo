
TARGET?=
OPTS?="--wave=wave.ghw"

SOURCES=src/sync.vhd \
		src/adc.vhd  \
		src/pwm.vhd  \
		src/ccd.vhd  \
		src/spi/spi_main.vhd

GHDL_ARGS=--workdir=$(realpath build) --std=08

target_name=$(shell basename $(1) | cut -d"." -f1)

all: build/tb_adc.o

build/%.o: $(SOURCES) tests/%.vhd
	ghdl -a $(GHDL_ARGS) $^
	@cd build && ghdl -e $(GHDL_ARGS) $(call target_name, $@)

run: $(TARGET)
	@cd build && ghdl -r $(GHDL_ARGS) $(call target_name, $^) $(OPTS)

view_wave: build/wave.ghw
	gtkwave $^

.PHONY: clean
clean:
	rm -rf build/*
