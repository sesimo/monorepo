
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_spi_sub is
    generic (
        G_DATA_WIDTH: integer := 8;
        G_CLK_FREQ: integer := 25_000_000;
        G_CFG_WIDTH: integer := 12
    );
end entity tb_spi_sub;

architecture bhv of tb_spi_sub is
    signal r_sclk: std_logic := '0';
    signal r_rst_n: std_logic := '0';
    signal r_cs_n: std_logic := '1';
    signal r_wr_data: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_rd_data: std_logic_vector(G_DATA_WIDTH-1 downto 0);

    signal r_miso: std_logic := '0';
    signal r_mosi: std_logic;

    signal r_rdy: std_logic;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
begin
    r_cs_n <= '0' after c_clk_period * 4;
    r_rst_n <= '1' after c_clk_period * 2;
    
    p_sclk: process
    begin
        wait for c_clk_period / 2;
        r_sclk <= '1';
        wait for c_clk_period / 2;
        r_sclk <= '0';
    end process p_sclk;

    -- Loopback
    r_mosi <= r_miso;

    u_spi: entity work.spi_sub(rtl) generic map(
        G_MODE => 1,
        G_DATA_WIDTH => G_DATA_WIDTH
    )
    port map(
        i_sclk => r_sclk,
        i_arst_n => r_rst_n,
        i_data => r_wr_data,

        i_mosi => r_mosi,
        i_cs_n => r_cs_n,
        o_miso => r_miso,

        o_data => r_rd_data,
        o_rdy => r_rdy
    );

    p_main: process
    begin
        wait until r_rst_n = '1';
        wait until r_cs_n = '0';

        r_wr_data <= "11010011";

        wait for 5000 ns;

        stop;
    end process p_main;
end architecture;
