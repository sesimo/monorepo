
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_adc is
    generic (
        G_CLK_FREQ: integer := 100_000_000;
        G_CLK_DIV: integer := 10
    );
end entity tb_adc;

architecture bhv of tb_adc is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';
    signal r_start: std_logic := '0';

    signal r_stconv: std_logic := '0';
    signal r_eoc: std_logic := '0';

    signal r_rd_en: std_logic;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
    constant c_mod_period: time := c_clk_period * G_CLK_DIV;
begin
    u_adc: entity work.ads8329(rtl) generic map(
        G_CLK_DIV => G_CLK_DIV
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_start => r_start,

        i_pin_eoc => r_eoc,
        o_pin_stconv => r_stconv,

        o_rd_en => r_rd_en
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

    p_convert: process
    begin
        if r_rst_n = '0' then
            wait until r_rst_n <= '1';
        end if;

        wait until r_stconv = '1';
        r_eoc <= '0';

        -- Total wait time: roughly 18 CCLKs at nominal freqency
        wait for 807 ns; 
        r_eoc <= '1';
    end process;

    p_main: process
    begin
        wait until r_rst_n = '1';

        for i in 0 to 1 loop
            assert r_stconv = '0'
            report "STconv should be low" severity failure;
            r_start <= '1';

            wait until r_stconv = '1' for c_mod_period*1.5;
            assert r_stconv = '1'
            report "STconv should be high" severity failure;
            r_start <= '0';

            wait until r_stconv = '0' for 120 ns;
            assert r_stconv = '0'
            report "STconv should have been cleared" severity failure;

            assert r_rd_en = '0'
            report "RD en should be low" severity failure;
            wait until (r_rd_en = '1' or r_eoc = '1') for 900 ns;
            assert r_eoc = '1'
            report "EOC should have been set high" severity failure;
            assert r_rd_en = '0'
            report "RD en should be kept low" severity failure;

            wait until r_rd_en = '1' for c_mod_period;
            assert r_rd_en = '1'
            report "RD en should be set high" severity failure;

            wait until r_rd_en = '0' for c_clk_period * 1.05;
            assert r_rd_en = '0'
            report "RD en should have been cleared" severity failure;

            wait for c_mod_period;
        end loop;

        stop;
    end process p_main;

end architecture bhv;
