
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_ccd is
    generic (
        G_CLK_FREQ: integer := 100_000_000;
        G_CFG_WIDTH: integer := 12
    );
end entity tb_ccd;

architecture bhv of tb_ccd is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';

    signal r_shutter: std_logic_vector(
        G_CFG_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(200, G_CFG_WIDTH));
    signal r_clk_speed: std_logic_vector(
        G_CFG_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(25, G_CFG_WIDTH));

    signal r_sh: std_logic;
    signal r_icg: std_logic;
    signal r_mclk: std_logic;

    signal r_start: std_logic;
    signal r_rdy: std_logic;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
begin
    u_ccd: entity work.tcd1304(rtl) generic map(
        G_CLK_FREQ => G_CLK_FREQ,
        G_CFG_WIDTH => G_CFG_WIDTH
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_shutter => r_shutter,
        i_clk_speed => r_clk_speed,
        i_start => r_start,

        o_pin_sh => r_sh,
        o_pin_icg => r_icg,
        o_pin_mclk => r_mclk,
        o_rdy => r_rdy
    );

    r_clk <= not r_clk after c_clk_period / 2;
    r_rst_n <= '1' after c_clk_period * 2;

    p_main: process
    begin
        wait until r_rst_n = '1';
        wait for c_clk_period * 20;
        r_start <= '1';
        wait for c_clk_period;
        r_start <= '0';
        wait until r_rdy = '1';

        stop;
    end process p_main;

end architecture bhv;

