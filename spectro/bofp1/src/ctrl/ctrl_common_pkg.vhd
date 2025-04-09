
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ctrl_common is
    type t_reg is (
        REG_STREAM,
        REG_SAMPLE,
        REG_RESET,
        REG_SHDIV1,
        REG_SHDIV2,
        REG_SHDIV3,
        REG_PRC_CONTROL, -- Processing control
        REG_STATUS
    );
    constant t_reg_len: integer := t_reg'pos(t_reg'high) + 1;

    subtype t_reg_vector is std_logic_vector(7 downto 0);
    type t_regmap is array(t_reg_len-1 downto 0) of t_reg_vector;

    constant c_regmap_default: t_regmap := (
        t_reg'pos(REG_SHDIV1) => std_logic_vector(to_unsigned(0, 8)),
        t_reg'pos(REG_SHDIV2) => std_logic_vector(to_unsigned(0, 8)),
        t_reg'pos(REG_SHDIV3) => std_logic_vector(to_unsigned(80, 8)),
        others => (others => '0')
    );
    
    -- brief Get the value of register `reg` in `regmap`
    -- param regmap Regmap to read value from
    -- param reg Reg to read
    -- return t_reg_vector Read register value
    function get_reg(regmap: t_regmap; reg: t_reg) return t_reg_vector;

    procedure set_reg(signal regmap: out t_regmap;
                      constant reg: t_reg; signal val: in t_reg_vector);

    function parse_reg(code: t_reg_vector) return t_reg;

    function is_write(code: t_reg_vector) return boolean;
end package ctrl_common;

package body ctrl_common is
    function get_reg(regmap: t_regmap; reg: t_reg) return t_reg_vector is
    begin
        return regmap(t_reg'pos(reg));
    end function get_reg;

    procedure set_reg(signal regmap: out t_regmap;
                      constant reg: t_reg; signal val: in t_reg_vector) is
    begin
        regmap(t_reg'pos(reg)) <= val;
    end procedure set_reg;

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
