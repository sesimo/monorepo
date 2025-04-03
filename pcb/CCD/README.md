[sesimo](https://n.varx.net/sesimo)

[2025-03-25_11-30-08.png](https://n.varx.net/sesimo/2025-03-25_11-30-08.png)
# Modules
## CCD

The [TCD1304DG](TCD1304DG_Web_Datasheet_en_20190108.pdf) CCD sensor was mounted to the board using 2.56mm bottom entry pin headers [WR-PHD 2.54 mm Socket Header Bottom Entry](https://www.we-online.com/en/components/products/PHD_2_54_SOCKET_HEADER_BOTTOM_ENTRY_6130XX15721#61301015721) allowing it to be changed or removed without desoldering it. The headers also allow for the CCD to be placed as close to the circuit board as possible to allow for optimal placement in the spectrometer bench.
A 100nF decoupling was added to the VDD pin based on recommendations from the datasheet. Further modules were also chosen based on the recommendations of the datasheet.
The CCD itself takes in Integration clear gate, Master clock and Shift gate to control its various functions, and it outputs an Output signal that contains the sensor values. This output value varies between 0.3v and 2.5v given a 4v supply voltage. 



[2025-03-24_11-58-06.png](https://n.varx.net/sesimo/2025-03-24_11-58-06.png)
## OP-Amp
To correct the offset of the output from the CCD, an [OPA365](https://www.ti.com/product/OPA365) OP-AMP was implemented with a 2 times output which outputs an inverted signal mapped to 5v to 0v(see below).

To achieve the amplification the following resistor setup was used:
```latex
R_{in} = 10k \Omega \\
R_{Feedback} = 20k \Omega \\
R_{out} = 100 \Omega \\
R_{Divider 1} = 20k \Omega \\
R_{Divider 2} = 10k \Omega
```
[2025-03-26_13-49-02.png](https://n.varx.net/sesimo/2025-03-26_13-49-02.png)
A 100nF decoupling capacitor was used on the V+ based on the recommendation from the datasheet. On the output a 100 Ohm resistor was used to limit the current and a 1nF capacitor to decouple, based on the recommendation of the datasheet.
To ensure that the ADC would not get too high of a signal, a 5v TVS diode was placed on the output to clamp +6v to ground.
The resulting circuit simulated gives the following values:
[v-sweep1.png](https://n.varx.net/sesimo/v-sweep1.png)[v-sweep2.png](https://n.varx.net/sesimo/v-sweep2.png)In these graphs the CCD is the OS signal from the CCD and the SIG is the output from the OP-Amp circuitry. It shows an output of 5V at 0V and 0V at 2.5V granting 5v of resolution for the ADC to measure.

## ADC
To convert the analog voltage signal to a digital measurement, an [ADS8329](https://www.ti.com/product/ADS8329) ADC (analog to digital converter) was used. The ADC chosen is a high accurate 16-bit device from Texas Instruments which communicates with SPI. 
To measure the OP-Amps output the ADC is configured with ground and 5v as reference points to compare against. A 3v3 reference is used for the internal logic as well as the SPI communication level.
[2025-03-26_14-14-55.png](https://n.varx.net/sesimo/2025-03-26_14-14-55.png)
## Hex inverter
To control the CCDs functionality a Hex inverter [SN74HC04](https://www.ti.com/product/SN74HC04) was used to drive the signals. This inverts the control signal going into the CCD but allows for a separate source to supply the inverted voltage. 
In this application any input higher than 3.15V would then output 0V to the CCD, and values under 1.35V would output a stable 4V to the CCD. This allows an FPGA or microcontroller whose output high is 3.3V or 5V to control the CCD even though it requires a 4v high signal.
To control the CCD SH, ØM and ICG is sent through the inverter and into the CCD.
A 100nF capacitor was placed on the VCC to decouple it.
[2025-03-26_14-16-07.png](https://n.varx.net/sesimo/2025-03-26_14-16-07.png)
## Connector
The CCD driver gets power and interfaces with FPGA and Microcontroller thru a single [WR-MM Male Connector](https://www.we-online.com/en/components/products/MM_1_27_MALE_CONNECTOR_W_O_LATCH_AND_WITH_POLARIZATION_69035710XX72#690357101472).
[2025-03-26_14-59-28.png](https://n.varx.net/sesimo/2025-03-26_14-59-28.png)

## Power
To power the driver, several regulators were used to give the board 4V and 3v3.
### 4V
An LPO 4v regulator [MIC5205](https://www.microchip.com/en-us/product/MIC5205) was used to supply the CCD, Hex inverter, and the reference for the ADC. 
A 1uF bypass capacitor and a 2.2uF capacitor on the output were added based on the recommendation from the datasheet.
[2025-03-24_11-33-42.png](https://n.varx.net/sesimo/2025-03-24_11-33-42.png)
### 3V3
An LPO 3v3 regulator [TLV757P](https://www.ti.com/product/TLV757P/part-details/TLV75733PDBVR) was used to supply the ADC with a logic reference for the SPI communication. 
A 1uF input decoupling and a 470nF output decoupling were used based on the recommendations in the datasheet.
[2025-03-24_11-33-17.png](https://n.varx.net/sesimo/2025-03-24_11-33-17.png)

# Design considerations
- The layout design of the modules was based on recommendations for each component's datasheet.
- Most component values were based on recommendations and calculated values from each component's datasheet
- The CCD was placed on the back to allow for it to be placed into the testbench without any other component touching or blocking a seal.
- The 0805 and 1206 package sizes were used to allow for hand soldering if necessary. This allows potensial swaps to be made if component values needed to be changed.
- To keep the signal ground clean, two separate ground planes were created. A signal ground and a power ground, connected with a simple net tie made from two pads that are soldered together.
