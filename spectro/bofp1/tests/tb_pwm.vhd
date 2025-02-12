
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_pwm is
    generic (
        G_CLK_FREQ: integer := 100_000_000;
        G_WIDTH: integer := 12
    );
end entity tb_pwm;

architecture bhv of tb_pwm is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';
    signal r_period: std_logic_vector(G_WIDTH-1 downto 0) := std_logic_vector(
        to_unsigned(250, G_WIDTH));
    signal r_pulse: std_logic_vector(G_WIDTH-1 downto 0) := std_logic_vector(
        to_unsigned(20, G_WIDTH));
    signal r_oclk: std_logic;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
begin
    u_pwm: entity work.pwm(rtl) generic map (
        G_WIDTH => G_WIDTH
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_period => r_period,
        i_pulse => r_pulse,
        o_clk => r_oclk
    );

    r_clk <= not r_clk after c_clk_period / 2;
    r_rst_n <= '1' after c_clk_period * 2;

    p_main: process
    begin
        wait until r_rst_n = '1';
        wait for 10000 ns;
        assert false report "test" severity note;

        stop;
    end process p_main;

end architecture bhv;
