
TARGET?=
OPTS?="--wave=wave.ghw"

SOURCES=src/sync.vhd \
		src/adc.vhd

GHDL_ARGS=--workdir=$(realpath build)

target_name=$(shell basename $(1) | cut -d"." -f1)

all: build/tb_adc.o

build/tb_%.o: $(SOURCES) tests/tb_%.vhd
	ghdl -a $(GHDL_ARGS) $^
	@cd build && ghdl -e $(GHDL_ARGS) $(call target_name, $@)

run: $(TARGET)
	@cd build && ghdl -r $(GHDL_ARGS) $(call target_name, $^) $(OPTS)

view_wave: build/wave.ghw
	gtkwave $^

.PHONY: clean
clean:
	rm -rf build/*
