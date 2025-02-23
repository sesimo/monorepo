
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package utils is
    -- Get the maximum value for an integer with the width `w`
    function int_max(w: integer) return integer;
end package utils;

package body utils is
    function int_max(w: integer) return integer is
    begin
        return 2**w -1;
    end function int_max;
end package body utils;
