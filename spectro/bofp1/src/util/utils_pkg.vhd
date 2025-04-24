
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package utils is
    -- Get the maximum value for an integer with the width `w`
    function int_max(w: integer) return integer;

    function const_div(dividend: unsigned; divisor: unsigned;
                       bits: integer) return unsigned;
end package utils;

package body utils is
    function int_max(w: integer) return integer is
    begin
        return 2**w -1;
    end function int_max;

    function const_div(dividend: unsigned; divisor: unsigned;
                       bits: integer) return unsigned is
        type t_div is record
            shift: integer range 0 to 36;
            mul: unsigned(39 downto 0);
        end record t_div;

        type t_div_lut is array(15 downto 0) of t_div;
        -- Shifts are given in: https://oeis.org/A346496
        -- Multipliers are given in: https://oeis.org/A346495
        constant lut: t_div_lut := (
            0 => (shift => 0, mul => resize(x"1", 40)), -- Invalid really
            1 => (shift => 0, mul => resize(x"1", 40)),
            2 => (shift => 1, mul => resize(x"1", 40)),
            3 => (shift => 33, mul => resize(x"aaaaaaab", 40)),
            4 => (shift => 2, mul => resize(x"1", 40)),
            5 => (shift => 34, mul => resize(x"cccccccd", 40)),
            6 => (shift => 34, mul => resize(x"aaaaaaab", 40)),
            7 => (shift => 35, mul => resize(x"124924925", 40)),
            8 => (shift => 3, mul => resize(x"1", 40)),
            9 => (shift => 33, mul => resize(x"38e38e39", 40)),
            10 => (shift => 35, mul => resize(x"cccccccd", 40)),
            11 => (shift => 35, mul => resize(x"ba2e8ba3", 40)),
            12 => (shift => 35, mul => resize(x"aaaaaaab", 40)),
            13 => (shift => 34, mul => resize(x"4ec4ec4f", 40)),
            14 => (shift => 36, mul => resize(x"124924925", 40)),
            15 => (shift => 35, mul => resize(x"88888889", 40))
        );

        variable div: t_div;
        variable tmp: unsigned(bits-1 downto 0);
    begin
        div := lut(to_integer(divisor));

        tmp := resize(dividend * div.mul, tmp'length);
        return resize(tmp srl div.shift, dividend'length);
    end function const_div;
end package body utils;
