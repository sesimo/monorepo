
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
            reset: in std_logic;
            main: out std_logic;
            sclk_adc: out std_logic;
            locked: out std_logic
        );
end entity clk_wizard;

architecture behaviour of clk_wizard is
    signal r_clkena_main: boolean;
    signal r_clkena_sclk: boolean;

    function calc_period(freq: integer) return time is
    begin
        return (1.0 / real(freq)) * (1 sec);
    end function calc_period;
begin
    clock_generator(main, r_clkena_main, calc_period(100_000_000), "Main CLK");
    clock_generator(sclk_adc, r_clkena_sclk, calc_period(25_000_000), "ADC SCLK");

    r_clkena_main <= true;
    r_clkena_sclk <= true;

end architecture behaviour;
