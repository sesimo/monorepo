
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

-- Mux pipeline stage signals, depending on its respective field in the PRC
-- register. If enabled, this uses the _pl signals to output, otherwise
-- the pipeline stage is skipped and _raw signals are used.
entity stage_ctrl is
    generic (
        C_FIELD: t_prc_ctrl
    );
    port (
        i_regmap: in t_regmap;

        i_data_raw: in std_logic_vector(15 downto 0);
        i_data_pl: in std_logic_vector(15 downto 0);
        i_rdy_raw: in std_logic;
        i_rdy_pl: in std_logic;
        i_busy_raw: in std_logic;
        i_busy_pl: in std_logic;

        o_data: out std_logic_vector(15 downto 0);
        o_busy: out std_logic;
        o_rdy: out std_logic;
        o_en: out std_logic
    );
end entity stage_ctrl;

architecture behaviour of stage_ctrl is
    signal r_ena: std_logic;
begin
    r_ena <= get_prc(i_regmap, C_FIELD);

    o_en <= r_ena;
    o_data <= i_data_pl when r_ena else i_data_raw;
    o_busy <= i_busy_pl when r_ena else i_busy_raw;
    o_rdy <= i_rdy_pl when r_ena else i_rdy_raw;
end architecture behaviour;
