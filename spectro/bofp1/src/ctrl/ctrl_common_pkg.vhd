
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ctrl_common is
    constant c_reg_width: integer := 4;

    type t_regmap is record
        shdiv1: std_logic_vector(7 downto 0);
        shdiv2: std_logic_vector(7 downto 0);
        shdiv3: std_logic_vector(7 downto 0);
    end record t_regmap;

    constant c_regmap_default: t_regmap := (
        shdiv1 => std_logic_vector(to_unsigned(0, 8)),
        shdiv2 => std_logic_vector(to_unsigned(0, 8)),
        shdiv3 => std_logic_vector(to_unsigned(80, 8))
    );

    type t_reg is (
        REG_STREAM,
        REG_SAMPLE,
        REG_RESET,
        REG_SHDIV1,
        REG_SHDIV2,
        REG_SHDIV3
    );
    subtype t_reg_vector is std_logic_vector(c_reg_width-1 downto 0);
    
    function parse_reg(code: t_reg_vector) return t_reg;

    function is_write(code: t_reg_vector) return boolean;
end package ctrl_common;

package body ctrl_common is

    function parse_reg(code: t_reg_vector)
    return t_reg is
        variable v_uval: unsigned(code'high-1 downto 0);
    begin
        v_uval := unsigned(code(v_uval'high downto 0));

        return t_reg'val(to_integer(v_uval)); 
    end function parse_reg;

    function is_write(code: t_reg_vector) return boolean is
    begin
        return code(code'high) = '1';
    end function is_write;

end package body ctrl_common;
