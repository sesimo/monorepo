
# Main clock
#IO_L12P_T1_MRCC_34 Sch=ddr3_clk[200]
set_property -dict { PACKAGE_PIN R2    IOSTANDARD SSTL135 } [get_ports { i_clk }];
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000}  [get_ports { i_clk }];


# Pmod Header JA. This contains both SPI buses; main (ADC) on the top and
# the sub (control interface) on the bottom.
# For both, the order of pins, from right to left on the connector, is:
# - SCLK
# - CS
# - MOSI
# MISO
#IO_L4P_T0_D04_14 Sch=ja_p[1]
set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { o_spi_main_sclk }];
#IO_L4N_T0_D05_14 Sch=ja_n[1]
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { o_spi_main_cs_n }];
#IO_L5P_T0_D06_14 Sch=ja_p[2]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { o_spi_main_mosi }];
#IO_L5N_T0_D07_14 Sch=ja_n[2]
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { i_spi_main_miso }];
#IO_L7P_T1_D09_14 Sch=ja_p[3]
set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS33 } [get_ports { i_spi_sub_sclk }];
#IO_L7N_T1_D10_14 Sch=ja_n[3]
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { i_spi_sub_cs_n }];
#IO_L8P_T1_D11_14 Sch=ja_p[4]
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { i_spi_sub_mosi }];
#IO_L8N_T1_D12_14 Sch=ja_n[4]
set_property -dict { PACKAGE_PIN N18   IOSTANDARD LVCMOS33 } [get_ports { o_spi_sub_miso }];

# Pmod Header JC. This contains the CCD signals on the top and the ADC signals
# on the bottom.
# On the top, the pin order, from right to left, is:
# - MCLK
# - SH
# - ICG
# - FIFO WMARK
# On the bottom, the pin order, from right to left, is:
# - STCONV
# - EOC
#IO_L18P_T2_A12_D28_14 Sch=jc1/ck_io[41]
set_property -dict { PACKAGE_PIN U15   IOSTANDARD LVCMOS33 } [get_ports { o_ccd_mclk }];
#IO_L18N_T2_A11_D27_14 Sch=jc2/ck_io[40]
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { o_ccd_sh }];
#IO_L15P_T2_DQS_RDWR_B_14 Sch=jc3/ck_io[39]
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { o_ccd_icg }];
#IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=jc4/ck_io[38]
set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { o_fifo_wmark }];
#IO_L16P_T2_CSI_B_14 Sch=jc7/ck_io[37]
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { o_adc_stconv }];
#IO_L19P_T3_A10_D26_14 Sch=jc8/ck_io[36]
set_property -dict { PACKAGE_PIN P13   IOSTANDARD LVCMOS33 } [get_ports { i_adc_eoc }]; 

## Configuration options, can be used for all designs
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## SW3 is assigned to a pin M5 in the 1.35v bank. This pin can also be used as
## the VREF for BANK 34. To ensure that SW3 does not define the reference voltage
## and to be able to use this pin as an ordinary I/O the following property must
## be set to enable an internal VREF for BANK 34. Since a 1.35v supply is being
## used the internal reference is set to half that value (i.e. 0.675v). Note that
## this property must be set even if SW3 is not used in the design.
set_property INTERNAL_VREF 0.675 [get_iobanks 34]
