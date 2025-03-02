
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ctrl_common is
    constant c_reg_width: integer := 4;

    type t_regmap is record
        clkdiv: std_logic_vector(7 downto 0);
        shdiv: std_logic_vector(7 downto 0);
    end record t_regmap;

    constant c_regmap_default: t_regmap := (
        clkdiv => std_logic_vector(to_unsigned(1, 8)),
        shdiv => std_logic_vector(to_unsigned(1, 8))
    );

    type t_reg is (
        REG_STREAM,
        REG_SAMPLE,
        REG_RESET,
        REG_CLKDIV,
        REG_SHDIV
    );
    subtype t_reg_vector is std_logic_vector(c_reg_width-1 downto 0);
    
    function parse_reg(code: t_reg_vector) return t_reg;
end package ctrl_common;

package body ctrl_common is

    function parse_reg(code: t_reg_vector)
    return t_reg is
        variable v_uval: unsigned(c_reg_width-1 downto 0);
    begin
        v_uval := unsigned(code(code'high downto code'high-v_uval'high));

        return t_reg'val(to_integer(v_uval)); 
    end function parse_reg;

end package body ctrl_common;
