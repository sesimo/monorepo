
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity ctrl is
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        o_ccd_sample: out std_logic;
        o_rst: out std_logic;

        i_sclk: in std_logic;
        i_cs_n: in std_logic;

        i_mosi: in std_logic;
        o_miso: out std_logic;

        i_fifo_empty: in std_logic;
        i_fifo_data: in std_logic_vector(15 downto 0);
        o_fifo_rd: out std_logic;
        o_regmap: out t_regmap
    );
end entity ctrl;

architecture behaviour of ctrl is
    signal r_sub_data: std_logic_vector(3 downto 0);
    signal r_sub_rdy: std_logic;
begin

    u_ctrl_main: entity work.ctrl_main(behaviour)
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            o_ccd_sample => o_ccd_sample,
            o_rst => o_rst,

            i_sub_data => r_sub_data,
            i_sub_rdy => r_sub_rdy,

            o_regmap => o_regmap
        );

    u_ctrl_sub: entity work.ctrl_sub(behaviour)
        generic map(
            G_DATA_WIDTH => 4
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_sclk => i_sclk,
            i_cs_n => i_cs_n,

            i_mosi => i_mosi,
            o_miso => o_miso,

            o_rdy => r_sub_rdy,
            o_data => r_sub_data,

            i_fifo_empty => i_fifo_empty,
            i_fifo_data => i_fifo_data,
            o_fifo_rd => o_fifo_rd
        );

end architecture behaviour;
