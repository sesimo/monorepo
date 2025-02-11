
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_adc is
    generic (
        G_RESOLUTION: integer := 16;
        G_CLK_FREQ: integer := 100_000_000
    );
end entity tb_adc;

architecture bhv of tb_adc is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';
    signal r_start: std_logic := '0';
    signal r_rdy: std_logic := '0';
    signal r_buf: std_logic_vector(G_RESOLUTION-1 downto 0);

    signal r_stconv: std_logic := '0';
    signal r_eoc: std_logic := '0';

    constant c_ads8329_pins: work.p_ads8329.t_pins := (
        i_stconv => r_stconv,
        o_eoc => r_eoc
    );

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
begin
    u_adc: entity work.ads8329(rtl) generic map(
        G_CLK_FREQ => G_CLK_FREQ,
        G_RESOLUTION => G_RESOLUTION
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_start => r_start,

        o_rdy => r_rdy,
        o_buf => r_buf
    );

    p_clk: process
    begin
        r_clk <= '0';
        wait for c_clk_period / 2;
        r_clk <= '1';
        wait for c_clk_period / 2;
    end process p_clk;

    p_rst: process
    begin
        r_rst_n <= '0';
        wait for c_clk_period * 3;
        r_rst_n <= '1';
        wait;
    end process p_rst;

    p_eoc: process
    begin
        wait for c_clk_period * 5;
        wait;
    end process p_eoc;

    p_main: process
    begin
        wait for c_clk_period * 1000;
        assert false report "test ended" severity error;

        wait;
    end process p_main;

end architecture bhv;
