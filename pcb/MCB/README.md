[sesimo](https://n.varx.net/sesimo)

[2025-03-31_11-43-06.png](https://n.varx.net/sesimo/2025-03-31_11-43-06.png)
# 
# Microcontroller board
To connect the FPGA to the desired client a microcontroller was chosen to allow for USB connections and to control the periphery  devices such as lights.

## I/O
The board connects the CCD’s ADC to the FPGA and the FPGA itself to the the microcontroller to reduce the amount of wires. 
The board also implements a JTAG connector for programming, two 3 pin connectors to control lights, and an array of GPIO pins to allow for other connections if nessesary. 
To power the board a 2 pin connector and a microUSB connector was implemented, where the USB is also the data connection for the client.

| Function | Pin number | MC ref | Connector pin | Endpoint |
|-----|---------------|----------|----------|----------|
| NC | 1 | VBAT | N/A | N/A |
| _Pin header_ | 2 | PC13 | 6 (**PH**) | N/A |
| _Pin header_ | 3 | PC14 | 3 (**PH**) | N/A |
| _Pin header_ | 4 | PC15 | 4 (**PH**) | N/A |
| OSC+ | 5 | OSC_IN | N/A | Crystal |
| OSC- | 6 | OSC_OUT | N/A | Crystal |
| Reset | 7 | NRST | N/A | Reset Button |
| _Pin header_ | 8 | PC0 | 5 (**PH**) | N/A |
| _Pin header_ | 9 | PC1 | 8 (**PH**) | N/A |
| _Pin header_ | 10 | PC2 | 7 (**PH**) | N/A |
| _Pin header_ | 11 | PC3 | 10 (**PH**) | N/A |
| GND | 12 | VSS | N/A | GND |
| 3V3 | 13 | VDD | N/A | 3V3 |
| _FPGA Conn_ | 14 | PA0 | 12 (**FPGA**) | N/A |
| _FPGA Conn_ | 15 | PA1 | 11 (**FPGA**) | N/A |
| _FPGA Conn_ | 16 | PA2 | 10 (**FPGA**) | N/A |
| _FPGA Conn_ | 17 | PA3 | 9 (**FPGA**) | N/A |
| _FPGA Conn_ | 18 | VSS | 8 (**FPGA**) | N/A |
| _FPGA Conn_ | 19 | VDD | 7 (**FPGA**) | N/A |
| SPI **CS** | 20 | PA4 | 6 (**FPGA**) | FPGA **SPI CS** |
| SPI **SCK** | 21 | PA5 | 5 (**FPGA**) | FPGA **SPI SCK** |
| SPI **MISO** | 22 | PA6 | 4 (**FPGA**) | FPGA **SPI MOSI** |
| SPI **MOSI** | 23 | PA7 | 3 (**FPGA**) | FPGA **SPI MISO** |
| **FIFO W** | 24 | PC4 | 2 (**FPGA**) | FPGA **FIFO_W** |
| **CCD DONE** | 25 | PC5 | 1 (**FPGA**) | FPGA **Busy** |
| LIGHT **LOGIC** | 26 | PB0 | 1 (**J6**) | LIGHT **ON/OFF** |
| LIGHT **PWM** | 27 | PB1 | 2 (**J6**) | LIGHT **SERVO** |
| GND | 28 | PB2 | N/A | N/A |
| LIGHT **PB10** | 29 | PB10 | 3 (**J6**) | N/A |
| LIGHT **PB11** | 30 | PB11 | 1 (**J5**) | N/A |
| NC | 31 | VSS | N/A | N/A |
| NC | 32 | GND | N/A | N/A |
| NC | 33 | PB12 | N/A | STATUS LIGHT |
| NC | 34 | PB13 | N/A | N/A |
| NC | 35 | PB14 | N/A | N/A |
| NC | 36 | PB15 | N/A | N/A |
| STATUS LIGHT | 37 | PC6 | N/A | STATUS LIGHT |
| NC | 38 | PC7 | N/A | N/A |
| NC | 39 | PC8 | N/A | N/A |
| NC | 40 | PC9 | N/A | N/A |
| NC | 41 | PA8 | N/A | N/A |
| NC | 42 | PA9 | N/A | N/A |
| NC | 43 | PA10 | N/A | N/A |
| USB **D-** | 44 | PA11 | N/A | USB data |
| USB **D+** | 45 | PA12 | N/A | USB data |
| JTAG **TMS** | 46 | PA13 | 7 (**JTAG**) | JTAG **JTMS** |
| NC | 47 | VDD | N/A | N/A |
| NC | 48 | VSS | N/A | N/A |
| JTAG **CK** | 49 | PA14 | 9 (**JTAG**) | JTAG **JTCK** |
| JTAG **DI** | 50 | PA15 | 5 (**JTAG**) | JTAG **JTDI** |
| _Pin header_ | 51 | PC10 | 17 (**PH**) | N/A |
| _Pin header_ | 52 | PC11 | 18 (**PH**) | N/A |
| _Pin header_ | 53 | PC12 | 15 (**PH**) | N/A |
| _Pin header_ | 54 | PD2 | 16 (**PH**) | N/A |
| JTAG **DO** | 55 | PB3 | 13 (**JTAG**) | JTAG **JTDO** |
| JTAG **NTRST** | 56 | PB4 | 3 (**JTAG**) | JTAG **JNTRST** |
| _Pin header_ | 57 | PB5 | 13 (**PH**) | N/A |
| _Pin header_ | 58 | PB6 | 14 (**PH**) | N/A |
| _Pin header_ | 59 | PB7 | 11 (**PH**) | N/A |
| GND | 60 | BOOT0 | N/A | N/A |
| _Pin header_ | 61 | PB8 | 12 (**PH**) | N/A |
| _Pin header_ | 62 | PB9 | 9 (**PH**) | N/A |
| JTAG **GND** | 63 | VSS | 4,6,8,10,12,14,16,18 (**JTAG**) |JTAG **Ground reference** |
| JTAG **REF** | 64 | VDD | 19 (**JTAG**) |JTAG **Voltage reference** |


## Microcontroller
[Datasheet - STM32F103xC, STM32F103xD, STM32F103xE - High-density performance line Arm®-based 32-bit MCU with 256 to 512KB Flash, USB, CAN, 11 timers, 3 ADCs, 13 communication interfaces](https://no.mouser.com/datasheet/2/389/stm32f103rc-1851170.pdf)
[stm32f103xc.png](https://n.varx.net/sesimo/stm32f103xc.png)

>**warning** Only the VDDA and VSSA pins were connected and acording to the datasheet VDD_x and VSS_x should also be connected.
> In an attempt to connect the ports the first verstion the VSS_4 pin was damaged and two microcontrollers were fried

## Power
[900](https://n.varx.net/sesimo/2025-03-31_11-52-21.png)
[2025-03-31_11-52-46.png](https://n.varx.net/sesimo/2025-03-31_11-52-46.png)
### 3v3
[2025-04-03_10-52-08.png](https://n.varx.net/sesimo/2025-04-03_10-52-08.png)
[2025-03-31_12-04-19.png](https://n.varx.net/sesimo/2025-03-31_12-04-19.png)
Standard USB has a voltage of 5V and the microcontroller requires a 3.3 voltage to operate. A stepdown power module from Wurth was used to supply the 3.3V by switching down the 5V. As per the datasheet the following values were chosen based on it’s recommendation:
```latex
R_{Feedback Top} = 100k \Omega \\
R_{Feedback Bottom} = 33k \Omega \\
C_{Feed-Forward} = 22pF \\
C_{IN} = 4.7\mu F \\
C_{OUT} = 10 \mu F \\
\rightarrow V_{OUT} \approx 3.3V
```

The layout was also inspired by the datasheets recommendation.

### Multi input
[2025-03-31_13-58-11.png](https://n.varx.net/sesimo/2025-03-31_13-58-11.png)
[2025-03-31_13-54-36.png](https://n.varx.net/sesimo/2025-03-31_13-54-36.png)
To allow for both the USB and the input connector to be used at the same time a [TPS2116](https://www.ti.com/product/TPS2116) power multiplexer was used.
[2025-03-20_11-55-56.png](https://n.varx.net/sesimo/2025-03-20_11-55-56.png)
The priotiry was set to an general input connector to power the board from a power supply, while the secondary was connected to the 5V supply from the USB micro connector. 
The powermux IC switches between the sources on the fly and allows for seemless swapping between the sources. 
For each source a green LED to indicate if they were connected was added, and a red LED to indicate which of the inputs powers the board currently.

Having the MODE pin connected to VIN1 sets the device into Priority mode where VIN1 would be the priority source and VIN2 would be the secoundary.
The PR1 pin determines if VIN1 should be selected or not based on the voltage thereashold. 
>**warning** Originaly a threashold of 500mV was desired and configures with the resistors. However the PRI1 and PRI2 locations are wrong in the schematic and proved difficult to change in the produced design. RPR1 was removed and shorted to allow for VIN1 to be prioritized. In this config any voltage over VIN1 would switch priority and allow for potensial lower then required voltages. 

The ST pin is an Open drain status pin that gets pulled low when VIN1 is not being used. In this setup it powers a red LED to indicate that an external power supply is being used.

## Status LED
[300](https://n.varx.net/sesimo/2025-03-31_14-30-46.png)A full RGB LED was implemented to allow for simple debugging or status indication while using the device.

The [1312020030000](https://www.we-online.com/en/components/products/datasheet/1312020030000.pdf) controller integrated LED utilizes a PWM signal to control the Red Green and Blue brightness values to create different colors.

## Clock
[2025-03-31_14-38-24.png](https://n.varx.net/sesimo/2025-03-31_14-38-24.png)[2025-03-31_14-38-44.png](https://n.varx.net/sesimo/2025-03-31_14-38-44.png)
For USB connectivity an exstrnal XTAL quartz crystal was needed and the [WE-XTAL Quartz Crystal](https://www.we-online.com/en/components/products/WE-XTAL?sq=830055901#830055901) from Wurth Electronics was selected due to its simular spesification to the recommended crystals for 8MHz.
### Component calculation
```latex
\text{Based on the formulas from the datasheet:} \\
C_L = \frac{C_p \times C_p}{C_p + C_p} + C_s \\
C_L \approx 18pF \\
C_s \approx 10pF \\
C_p \rightarrow 16pF \\
\text{Since 16pF was difficult to find the closet avalible was 15pF} \\
\rightarrow C_3 / C_4 = 15pF \\
\text{The R1 resistor was chosen based on recommendations from the datasheet for 8Mhz crystals} \\
\rightarrow R_1 = 200k \Omega
```
>**note** Two 15pF capacitor([WCAP-CSGP MLCCs 10 V(DC)](https://www.we-online.com/en/components/products/WCAP-CSGP-10VDC?sq=885012006003#885012006003)) were placed in paralell to the crystal. A 200Kohm resistor ([560112116060](https://www.we-online.com/en/components/products/WRIS-RSKS#560112116060)) was also added in series to the OSC_out pin as recommended by the datasheet.

## Connectors

### JTAG
#### Programmer side:
To connect the J-link programmer to the microcontroller a JTAG cable was made using a [WR-BHD 2.54 mm Female IDC Connector](https://www.we-online.com/en/components/products/BHD_2_54_FEMALE_IDC_CONNECTOR_WITH_STRAIN_RELIEF_6120XX23021#61202023021) with the following pinout:
[181129_JTAG.svg](https://n.varx.net/sesimo/181129_JTAG.svg)
#### Wire
A [WR-CAB 1.27 mm Ribbon Flat Cable](https://www.we-online.com/en/components/products/CAB_1_27_RIBBON_FLAT_CAB_6391XX15521CAB_3#63912015521CAB) was used between the programmer and the microcontroller board

#### Board side
[2025-04-03_11-12-33.png](https://n.varx.net/sesimo/2025-04-03_11-12-33.png)
On the board side a [WR-MM Female Angled Connector](https://www.we-online.com/en/components/products/MM_1_27_FEMALE_ANGLED_CONNECTOR_WITH_LATCH_AND_POLARIZATION_69036819XX72#690368192072) was added with the same pinout structure as the JTAG connector and was connected to the microcontoller with the following pinout:
| Pin | J_link | Microcontroller | 
|----------|----------|----------|
| VTref | 1 | VDD_3(**64**) |
| nTRST | 3 | PB4(**56**) |
| TDI | 5 | PA15(**50**) |
| TMS | 7 | PA13(**46**) |
| TCK | 9 | PA14(**49**) |
| RTCK | 11 | VSS_3(**63**) |
| TDO | 13 | PB3(**55**) |
| nRST | 15 | NRST(**7**) |
| 5V | 19 | NC |
| GND | 4,6,8,10,12,14,16,18 | VSS_3(**63**) |
### USB
To connect the microcontroller to the client computer, a [WR-COM Micro USB 2.0 SMT Type B connector](https://www.we-online.com/en/components/products/COM_MICRO_SMT_TYPE_B_HORIZONTAL_HIGH_CURRENT#629105150521) was used to allow for power and communtication. It was directy connected to the dedicated USB pins on the microcontroller and given two 10kOhm resistors on the data lines as recommended by the **several online forums**. 

>**note** High-speed USB interfaces can generate significant electromagnetic interference if not properly designed. To minimize EMI:
```md
- Use ground planes to provide a low-impedance return path
- Implement proper shielding for USB connectors
- Use ferrite beads or common-mode chokes on differential pairs when necessary
- Keep high-speed signals away from board edges
- Use stitching vias to connect ground planes on different layers
Implement proper filtering on power lines
```

The tracing for the USB was done to maintain the same distance between the traces and the same length where possible.
[2025-04-03_11-10-41.png](https://n.varx.net/sesimo/2025-04-03_11-10-41.png)
MicroUSB slave to host configuration:[schkT.jpg](https://n.varx.net/sesimo/schkT.jpg)
Microcontroller to USB connector configuration:[micro-USB-circuit-diagram.png](https://n.varx.net/sesimo/micro-USB-circuit-diagram.png)
### Power
[x300](https://n.varx.net/sesimo/2025-04-03_11-23-02.png)
To power the board from a different source then the USB, a [WR-TBL Series 8050 - 2.50 mm Screwless SMT connector](https://www.we-online.com/en/components/products/TBL_2_50_8050_SCREWLESS_SMT_HORIZONTAL_ENTRY_6918050103XX#691805010302) was used to connect V_in and Ground. For the board to function correctly this has to be a 5V source.

### CCD
[x400](https://n.varx.net/sesimo/2025-04-03_11-27-02.png)
Connecting the CCD to the Microcontroller board was done using a [WR-MM Female Angled Connector](https://www.we-online.com/en/components/products/MM_1_27_FEMALE_ANGLED_CONNECTOR_WITH_LATCH_AND_POLARIZATION_69036819XX72_2#690368191472) that allowed a direct connection to the CCD board. The connector powers the CCD board and connects the control sigals for the CCD aswell as the SPI to communicate with the ADC.

### Light control
[2025-04-03_11-13-22.png](https://n.varx.net/sesimo/2025-04-03_11-13-22.png)To control the lightsource of the spectrometer, a servo was implemented. and to control this servo a dedicated PWM and logic pin from the microcontroller needed to be connected. To do this two [WR-TBL Series 8050 - 2.50 mm Screwless SMT connectors](https://www.we-online.com/en/components/products/TBL_2_50_8050_SCREWLESS_SMT_HORIZONTAL_ENTRY_6918050103XX#691805010303) were added that would connect those pins aswell as two others incase. 5V and Ground was also added to one of the connectors to power the servo.

### GPIO
Incase more GPIO pins were needed from the microcontroller a [WR-PHD 2.54 mm THT Angled Dual Pin Header](https://www.we-online.com/en/components/products/PHD_2_54_THT_ANGLED_DUAL_PIN_HEADER_6130XX21021#61302021021) was added to allow for easier connection and testing.
