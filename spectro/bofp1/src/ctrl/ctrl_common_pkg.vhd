
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ctrl_common is
    type t_reg is (
        REG_STREAM_RAW,
        REG_STREAM_PL,
        REG_SAMPLE,
        REG_RESET,
        REG_SHDIV1,
        REG_SHDIV2,
        REG_SHDIV3,
        REG_PRC_CONTROL, -- Processing control
        REG_MOVING_AVG_N,
        REG_TOTAL_AVG_N,
        REG_STATUS,
        REG_DC_CALIB,
        REG_FLUSH
    );
    constant t_reg_len: integer := t_reg'pos(t_reg'high) + 1;

    type t_prc_ctrl is (
        PRC_WMARK_SRC,
        PRC_BUSY_SRC,
        PRC_TOTAVG_ENA,
        PRC_MOVAVG_ENA,
        PRC_DC_ENA
    );

    subtype t_reg_vector is std_logic_vector(7 downto 0);
    type t_regmap is array(t_reg_len-1 downto 0) of t_reg_vector;

    constant c_regmap_default: t_regmap := (
        t_reg'pos(REG_SHDIV1) => std_logic_vector(to_unsigned(0, 8)),
        t_reg'pos(REG_SHDIV2) => std_logic_vector(to_unsigned(0, 8)),
        t_reg'pos(REG_SHDIV3) => std_logic_vector(to_unsigned(80, 8)),
        t_reg'pos(REG_MOVING_AVG_N) => std_logic_vector(to_unsigned(1, 8)),
        t_reg'pos(REG_TOTAL_AVG_N) => std_logic_vector(to_unsigned(2, 8)),
        t_reg'pos(REG_PRC_CONTROL) => (
            t_prc_ctrl'pos(PRC_WMARK_SRC) => '0',
            t_prc_ctrl'pos(PRC_BUSY_SRC) => '0',
            t_prc_ctrl'pos(PRC_TOTAVG_ENA) => '1',
            t_prc_ctrl'pos(PRC_MOVAVG_ENA) => '1',
            t_prc_ctrl'pos(PRC_DC_ENA) => '1',
            others => '0'
        ),
        others => (others => '0')
    );
    
    -- brief Get the value of register `reg` in `regmap`
    -- param regmap Regmap to read value from
    -- param reg Reg to read
    -- return t_reg_vector Read register value
    function get_reg(regmap: t_regmap; reg: t_reg) return t_reg_vector;

    -- brief Set register
    -- param regmap Register map to write to
    -- param reg Register to write to
    -- param val Value to write
    procedure set_reg(signal regmap: out t_regmap;
                      constant reg: in t_reg;
                      constant val: in t_reg_vector);

    -- brief Get bit at index `idx` in the PRC register
    -- param regmap Regmap to access
    -- param idx Index to access bit at
    -- return std_logic
    function get_prc(regmap: t_regmap; idx: t_prc_ctrl) return std_logic;

    -- brief Parse register represented in `code`
    -- param code Unparsed register
    -- return t_reg Parsed register
    function parse_reg(code: t_reg_vector) return t_reg;

    -- brief Check if code is a write operation
    --
    -- A write operation is indicated by MSB=1
    --
    -- param code Command code
    -- return bool
    -- retval true Write operation
    -- retval false Read operation
    function is_write(code: t_reg_vector) return boolean;

    type t_err is (
        ERR_FIFO_RAW_OVERFLOW,
        ERR_FIFO_RAW_UNDERFLOW,
        ERR_FIFO_PL_OVERFLOW,
        ERR_FIFO_PL_UNDERFLOW,
        ERR_DC_UNDERFLOW
    );
    constant c_err_len: integer := t_err'pos(t_err'high) + 1;
    subtype t_err_bitmap is std_logic_vector(c_err_len-1 downto 0);

    -- brief Get the error slot, that is the bit in the bitmap, for the
    -- given error code `err`
    function get_err_slot(bitmap: t_reg_vector; err: t_err) return std_logic;

    -- brief Set error in bitmap
    procedure set_err(signal bitmap: out t_err_bitmap; constant err: in t_err;
                      constant val: in std_logic);

end package ctrl_common;

package body ctrl_common is
    function get_reg(regmap: t_regmap; reg: t_reg) return t_reg_vector is
    begin
        return regmap(t_reg'pos(reg));
    end function get_reg;

    procedure set_reg(signal regmap: out t_regmap;
                      constant reg: in t_reg;
                      constant val: in t_reg_vector) is
    begin
        regmap(t_reg'pos(reg)) <= val;
    end procedure set_reg;

    function get_prc(regmap: t_regmap; idx: t_prc_ctrl) return std_logic is
    begin
        return get_reg(regmap, REG_PRC_CONTROL)(t_prc_ctrl'pos(idx));
    end function get_prc;

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

    function get_err_slot(bitmap: t_reg_vector; err: t_err) return std_logic is
    begin
        return bitmap(t_err'pos(err));
    end function get_err_slot;

    procedure set_err(signal bitmap: out t_err_bitmap; constant err: in t_err;
                      constant val: in std_logic) is
    begin
        bitmap(t_err'pos(err)) <= val;
    end procedure set_err;

end package body ctrl_common;
