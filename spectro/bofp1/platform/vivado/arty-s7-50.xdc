
# Main clock
#IO_L13P_T2_MRCC_15 Sch=uclk
#set_property -dict { PACKAGE_PIN F14   IOSTANDARD LVCMOS33 } [get_ports { i_clk }];
#create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.667} [get_ports { i_clk }];
#IO_L12P_T1_MRCC_34 Sch=ddr3_clk[200]
#create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} -add [get_ports i_clk]
set_property -dict {PACKAGE_PIN R2 IOSTANDARD SSTL135} [get_ports i_clk]

#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets i_spi_sub_sclk_IBUF]

## Pmod header JA
# This contains the high-speed pins to the CCD board. From
# right to left, the top row has the pins:
# - ADC SPI SCLK
# - ADC SPI MOSI
# - ADC SPI MISO
# - CCD MCLK
# And the bottom row has the pins, from right to left:
# - CCD SH
#IO_L4P_T0_D04_14 Sch=ja_p[1]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports o_spi_main_sclk]
#IO_L4N_T0_D05_14 Sch=ja_n[1]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports o_spi_main_mosi]
#IO_L5P_T0_D06_14 Sch=ja_p[2]
#set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports i_spi_main_miso]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports o_ccd_mclk]
#IO_L5N_T0_D07_14 Sch=ja_n[2]
#set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports o_ccd_mclk]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports i_spi_main_miso]
#IO_L7P_T1_D09_14 Sch=ja_p[3]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports o_ccd_sh]
#IO_L7N_T1_D10_14 Sch=ja_n[3]
#set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { i_spi_sub_cs_n }];
#IO_L8P_T1_D11_14 Sch=ja_p[4]
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { i_spi_sub_mosi }];
#IO_L8N_T1_D12_14 Sch=ja_n[4]
#set_property -dict { PACKAGE_PIN N18   IOSTANDARD LVCMOS33 } [get_ports { o_spi_sub_miso }];

## Pmod Header JB
# This contains high speed connections to the MCU. From right to left, the top
# row has the pins:
# - MCU SCLK
# - MCU MOSI
# - MCU MISO
#IO_L9P_T1_DQS_14 Sch=jb_p[1]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports i_spi_sub_sclk]
#IO_L9N_T1_DQS_D13_14 Sch=jb_n[1]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports i_spi_sub_mosi]
#IO_L10P_T1_D14_14 Sch=jb_p[2]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports o_spi_sub_miso]
#IO_L10N_T1_D15_14 Sch=jb_n[2]
#set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { jb[3] }];
##IO_L11P_T1_SRCC_14 Sch=jb_p[3]
#set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { jb[4] }];
##IO_L11N_T1_SRCC_14 Sch=jb_n[3]
#set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { jb[5] }];
##IO_L12P_T1_MRCC_14 Sch=jb_p[4]
#set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { jb[6] }];
##IO_L12N_T1_MRCC_14 Sch=jb_n[4]
#set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { jb[7] }];

## Pmod Header JC
# This contains low speed connections to the CCD board. From right to left, the
# top row has the pins:
# - ADC SPI CS
# - ADC STconv
# - ADC EOC
# - CCD ICG
#IO_L18P_T2_A12_D28_14 Sch=jc1/ck_io[41]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports o_spi_main_cs_n]
#IO_L18N_T2_A11_D27_14 Sch=jc2/ck_io[40]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports o_adc_stconv]
#IO_L15P_T2_DQS_RDWR_B_14 Sch=jc3/ck_io[39]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports i_adc_eoc]
#IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=jc4/ck_io[38]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports o_ccd_icg]
##IO_L16P_T2_CSI_B_14 Sch=jc7/ck_io[37]
#set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { jc[4] }];
##IO_L19P_T3_A10_D26_14 Sch=jc8/ck_io[36]
#set_property -dict { PACKAGE_PIN P13   IOSTANDARD LVCMOS33 } [get_ports { jc[5] }];
##IO_L19N_T3_A09_D25_VREF_14 Sch=jc9/ck_io[35]
#set_property -dict { PACKAGE_PIN R13   IOSTANDARD LVCMOS33 } [get_ports { jc[6] }];
##IO_L20P_T3_A08_D24_14 Sch=jc10/ck_io[34]
#set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { jc[7] }];

## Pmod Header JD
# This contain low speed signals to the MCU. From right to left, the top row has
# the pins:
# - MCU SPI CS
# - CCD busy
# - Fifo watermark
#IO_L20N_T3_A07_D23_14 Sch=jd1/ck_io[33]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports i_spi_sub_cs_n]
#IO_L21P_T3_DQS_14 Sch=jd2/ck_io[32]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports o_ccd_busy]
#IO_L21N_T3_DQS_A06_D22_14 Sch=jd3/ck_io[31]
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports o_fifo_wmark]
##IO_L22P_T3_A05_D21_14 Sch=jd4/ck_io[30]
#set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports { jd[3] }];
##IO_L22N_T3_A04_D20_14 Sch=jd7/ck_io[29]
#set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports { jd[4] }];
##IO_L23P_T3_A03_D19_14 Sch=jd8/ck_io[28]
#set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { jd[5] }];
##IO_L23N_T3_A02_D18_14 Sch=jd9/ck_io[27]
#set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { jd[6] }];
##IO_L24P_T3_A01_D17_14 Sch=jd10/ck_io[26]
#set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { jd[7] }];

#IO_L11N_T1_SRCC_15
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS33} [get_ports i_rst_n]

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


