
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_adc is
    generic (
        G_RESOLUTION: integer := 16;
        G_CLK_FREQ: integer := 100_000_000;
        G_CLK_DIV: integer := 10
    );
end entity tb_adc;

architecture bhv of tb_adc is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';
    signal r_start: std_logic := '0';
    signal r_busy: std_logic := '0';

    signal r_stconv: std_logic := '0';
    signal r_eoc: std_logic := '0';

    signal r_spi_enable: std_logic := '0';
    signal r_spi_rdy: std_logic := '0';

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
    constant c_mod_period: time := c_clk_period * G_CLK_DIV;
begin
    u_adc: entity work.ads8329(rtl) generic map(
        G_RESOLUTION => G_RESOLUTION,
        G_CLK_DIV => G_CLK_DIV
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_start => r_start,

        i_pin_eoc => r_eoc,
        o_pin_stconv => r_stconv,

        o_spi_enable => r_spi_enable,
        i_spi_rdy => r_spi_rdy,

        o_busy => r_busy
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

    p_main: process
    begin
        wait until r_rst_n = '1';
        wait for c_mod_period;

        -- Start conversion
        assert r_busy = '0' report "Busy should not be set" severity failure;
        assert r_stconv = '0' report "STconv should not be set" severity failure;
        r_start <= '1';

        -- Wait for conversion to have started, signal end of conversion
        wait for c_mod_period;
        assert r_busy = '1' report "Busy should be set" severity failure;
        assert r_stconv = '1' report "STconv should be set" severity failure;
        assert r_spi_enable = '0' report "SPI enable should not be set"
            severity failure;
        r_eoc <= '1';
        r_start <= '0';

        -- Start SPI read, signal read done
        wait for c_mod_period;
        assert r_spi_enable = '1' report "SPI enable should be set"
            severity failure;
        r_spi_rdy <= '1';
        
        -- Wait for read to complete
        wait for c_mod_period;
        assert r_busy = '0' report "Busy should be cleared" severity failure;

        wait for c_mod_period * 2;
        assert r_busy = '0' report "Should remain busy" severity failure;
        stop;
    end process p_main;

end architecture bhv;
