
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_ccd is
    generic (
        G_CLK_FREQ: integer := 100_000_000;
        G_CFG_WIDTH: integer := 12;

        G_MCLK_FREQ: integer := 4_000_000;
        G_SH_FREQ: integer := 1_000_000;

        G_NUM_ELEMENTS: integer := 3696
    );
end entity tb_ccd;

architecture bhv of tb_ccd is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';

    function calc_speed(freq_hz: integer) return std_logic_vector is
        variable v_scale: integer;
    begin
        v_scale := G_CLK_FREQ / freq_hz;

        return std_logic_vector(to_unsigned(v_scale, G_CFG_WIDTH));
    end function calc_speed;

    subtype t_speed_cfg is std_logic_vector(G_CFG_WIDTH-1 downto 0);
    signal r_shutter: t_speed_cfg := calc_speed(G_SH_FREQ);
    signal r_clk_speed: t_speed_cfg := calc_speed(G_MCLK_FREQ);

    signal r_sh: std_logic;
    signal r_icg: std_logic;
    signal r_mclk: std_logic;

    signal r_start: std_logic;
    signal r_data_rdy: std_logic;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
    constant c_mclk_period: time := c_clk_period * to_integer(unsigned(r_clk_speed));
    constant c_dclk_period: time := c_mclk_period * 4;
begin
    u_ccd: entity work.tcd1304(rtl) generic map(
        G_CLK_FREQ => G_CLK_FREQ,
        G_CFG_WIDTH => G_CFG_WIDTH,
        G_NUM_ELEMENTS => G_NUM_ELEMENTS
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_sh_div => r_shutter,
        i_mclk_div => r_clk_speed,
        i_start => r_start,

        o_pin_sh => r_sh,
        o_pin_icg => r_icg,
        o_pin_mclk => r_mclk,
        o_data_rdy => r_data_rdy
    );

    r_clk <= not r_clk after c_clk_period / 2;
    r_rst_n <= '1' after c_clk_period * 2;

    p_main: process
    begin
        r_start <= '0';

        wait until r_rst_n = '1';
        assert r_icg = '0' report "ICG should be low" severity failure;

        wait until r_data_rdy = '1' for c_dclk_period * 10;
        assert r_data_rdy = '0'
        report "Data rdy should not be signaled" severity failure;

        r_start <= '1';
        wait for c_clk_period;
        r_start <= '0';

        for i in 1 to G_NUM_ELEMENTS loop
            wait until r_data_rdy = '1' for c_dclk_period;
            assert r_data_rdy = '1'
            report "Data rdy should have been signaled";

            assert r_icg = '1'
            report "ICG should be high" severity failure;

            wait until r_data_rdy = '0' for c_dclk_period;
            assert r_data_rdy = '0'
            report "Data rdy should have been cleared" severity failure;
        end loop;

        wait until r_icg = '0' for c_mclk_period;
        assert r_icg = '0' report "ICG should have been cleared" severity failure;

        wait until r_data_rdy = '1' for c_dclk_period * 10;
        assert r_data_rdy = '0'
        report "Data rdy should not be signaled anymore" severity failure;

        -- For better waveform represenentation
        wait for c_dclk_period * 2;

        stop;
    end process p_main;

end architecture bhv;

