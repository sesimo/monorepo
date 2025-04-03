[sesimo](https://n.varx.net/sesimo)
# Intro
To interface with the FPGA a “breakout” card was designed to allow for easier connection and debugging of the FPGA’s signals.
[2025-03-27_10-02-47.png](https://n.varx.net/sesimo/2025-03-27_10-02-47.png)The board directly interfaces with the [Arty S7](https://digilent.com/reference/programmable-logic/arty-s7/start) board
ports and has a [WR-MM Female SMT Connector](https://www.we-online.com/en/components/products/MM_1_27_SMT_FEMALE_CONNECTOR_WITH_LATCH_AND_POLARIZATION_69036729XX76_2#690367292676) that connects to the microcontroller and CCD modules.
To allow for easier debugging test points were added to each port together pin headers for reference voltage and ground. These can be connected to an oscilloscope to verify the signals to and from the FPGA.
[2025-03-27_10-04-53.png](https://n.varx.net/sesimo/2025-03-27_10-04-53.png)
# Pinout
| Name | Pin number | FPGA ref | Cable pin | Endpoint |
|----------|----------|----------|----------|----------|
| SCLK **_(ADC)_** | 1 **_(HS)_** | L17 | 1 | SCLK(**15**) |
| MOSI **_(ADC)_** | 2 **_(HS)_** | L18 | 4 | SDO(**13**) |
| MISO **_(ADC)_** | 3 **_(HS)_** | M14 | 2 | SDI(**12**) |
| MCLK **_(CCD)_** | 4 **_(HS)_** | N14 | 8 | **~ØM** |
| SH **_(CCD)_** | 5 **_(HS)_** | M16 | 9 | **~SH** |
| SCLK **_(MCU)_** | 9 **_(HS)_** | P17 | 22 | PA5(**21**) |
| MOSI **_(MCU)_** | 10 **_(HS)_** | P18 | 24 | PA7(**23**) |
| MISO **_(MCU)_** | 11 **_(HS)_** | R18 | 23 | PA6(**22**) |
| SPI CS **_(ADC)_** | 17 **_(LS)_** | U15 | 3 | CS(**11**) |
| STCONV **_(ADC)_** | 18 **_(LS)_** | V16 | 6 | CONVST(**9**) |
| EOC **_(ADC)_** | 19 **_(LS)_** | U17 | 6 | EOC(**11**) |
| ICG **_(CCD)_** | 20 **_(LS)_** | U18 | 7 | **~ICG** |
| SPI CS **_(MCU)_** | 25 **_(LS)_** | V15 | 21 | PA4(**20**) |
| Busy / _CCD_DONE_ **_(MCU)_** | 26 **_(LS)_** | U12 | 26 | PC5(**25**) |
| Fido-W **_(MCU)_** | 27 **_(LS)_** | V13 | 27 | PC4(**24**) |
