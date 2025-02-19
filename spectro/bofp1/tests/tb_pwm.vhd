
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_pwm is
    generic (
        G_CLK_FREQ: integer := 100_000_000;
        G_WIDTH: integer := 12;

        G_PERIOD_CYC: integer := 250;
        G_PULSE_CYC: integer := 20
    );
end entity tb_pwm;

architecture bhv of tb_pwm is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';
    signal r_period: std_logic_vector(G_WIDTH-1 downto 0) := std_logic_vector(
        to_unsigned(G_PERIOD_CYC, G_WIDTH));
    signal r_pulse: std_logic_vector(G_WIDTH-1 downto 0) := std_logic_vector(
        to_unsigned(G_PULSE_CYC, G_WIDTH));
    signal r_oclk: std_logic;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);

    constant c_high_time: time := c_clk_period * G_PULSE_CYC;
    constant c_low_time: time := c_clk_period * (G_PERIOD_CYC - G_PULSE_CYC);
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
        wait until rising_edge(r_oclk) for c_clk_period * 2;
        assert r_oclk = '1'
        report "Oclk should have been started" severity failure;

        report "High time: " & time'image(c_high_time) severity note;
        report "Low time: " & time'image(c_low_time) severity note;
        
        for i in 0 to 10 loop
            wait until falling_edge(r_oclk);
            assert falling_edge(r_oclk) and r_oclk'delayed(c_high_time) = '1'
            report "Oclk should be high" severity failure;

            wait until rising_edge(r_oclk);
            assert r_oclk'delayed(c_low_time) = '0'
            report "Oclk should be low" severity failure;
        end loop;

        wait for c_clk_period * 10;

        stop;
    end process p_main;

end architecture bhv;
