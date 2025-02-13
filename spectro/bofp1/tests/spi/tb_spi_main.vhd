
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_spi_main is
    generic (
        G_DATA_WIDTH: integer := 8;
        G_CLK_FREQ: integer := 100_000_000;
        G_CFG_WIDTH: integer := 12
    );
end entity tb_spi_main;

architecture bhv of tb_spi_main is
    signal r_clk: std_logic := '1';
    signal r_rst_n: std_logic := '0';
    signal r_start: std_logic := '0';
    signal r_wr_data: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_rd_data: std_logic_vector(G_DATA_WIDTH-1 downto 0);

    signal r_miso: std_logic := '0';
    signal r_mosi: std_logic;
    signal r_sclk: std_logic;
    
    signal r_busy: std_logic;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
begin
    r_clk <= not r_clk after c_clk_period / 2;
    r_rst_n <= '1' after c_clk_period * 2;

    -- Loopback
    r_miso <= r_mosi;

    u_spi: entity work.spi_main(rtl) generic map(
        G_MODE => 0,
        G_CLK_DIV => 4,
        G_DATA_WIDTH => G_DATA_WIDTH
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_start => r_start,
        i_data => r_wr_data,

        i_miso => r_miso,
        o_sclk => r_sclk,
        o_mosi => r_mosi,

        o_data => r_rd_data,
        o_busy => r_busy
    );

    p_main: process
    begin
        wait until r_rst_n = '1';
        wait for c_clk_period * 10;

        r_wr_data <= "11010011";
        r_start <= '1';

        wait for c_clk_period;
        r_start <= '0';

        wait for 5000 ns;

        stop;
    end process p_main;
end architecture;
