
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity clk_wizard is
        port (
            clk_in1: in std_logic;
            main: out std_logic;
            sclk_adc: out std_logic;
            sclk2_adc: out std_logic;
            locked: out std_logic
        );
end entity clk_wizard;

architecture behaviour of clk_wizard is
    signal r_clkena_main: boolean;
    signal r_clkena_sclk: boolean;
    signal r_clkena_sclk2: boolean;

    function calc_period(freq: integer) return time is
    begin
        return (1.0 / real(freq)) * (1 sec);
    end function calc_period;
begin
    clock_generator(main, r_clkena_main, calc_period(100_000_000), "Main CLK");
    clock_generator(sclk_adc, r_clkena_sclk, calc_period(16_666_667), "ADC SCLK");
    clock_generator(sclk2_adc, r_clkena_sclk2, calc_period(16_666_667*2), "ADC SCLK2");

    p_enable: process(clk_in1)
    begin
        if rising_edge(clk_in1) then
            r_clkena_main <= true;
            r_clkena_sclk <= true;
            r_clkena_sclk2 <= true;
        end if;
    end process p_enable;

end architecture behaviour;
