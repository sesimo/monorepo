
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_counter is
end entity tb_counter;

architecture bhv of tb_counter is
    signal r_clk: std_logic;
    signal r_clkena: boolean;

    signal r_c1_out: std_logic;
    signal r_c2_out: std_logic;

    constant c_scope: string := C_TB_SCOPE_DEFAULT;

    signal r_rst_n: std_logic := '0';
begin
    clock_generator(r_clk, r_clkena, 10 ns, "Main");

    u_counter1: entity work.counter(rtl)
        generic map(
            G_WIDTH => 8
        )
        port map(
            i_clk => r_clk,
            i_rst_n => r_rst_n,
            i_en => '1',
            i_cyc_cnt => std_logic_vector(to_unsigned(100, 8)),
            o_int => r_c1_out
        );

    u_counter2: entity work.counter(rtl)
        generic map(
            G_WIDTH => 8
        )
        port map(
            i_clk => r_clk,
            i_rst_n => r_rst_n,
            i_en => r_c1_out,
            i_cyc_cnt => std_logic_vector(to_unsigned(255, 8)),
            o_int => r_c2_out
        );

    p_main: process
        procedure release_reset is
        begin
            r_rst_n <= '1';
        end procedure release_reset;
        
        variable v_last: time;
    begin
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);
        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Simulation setup", c_scope);
        r_clkena <= true;

        wait for 10 ns;

        log(ID_LOG_HDR, "Start simulation", c_scope);
        ------------------------------------------------------------------------
        release_reset;
        wait for 1 ps;

        wait until r_c2_out = '1';
        v_last := now;
        wait until r_c2_out = '1';
        check_value(
            now - v_last,
            10 ns * (100 * 255),
            "Value was 1 X ns ago",
            c_scope
        );

        -- End simulation
        ------------------------------------------------------------------------
        log(ID_LOG_HDR, "End simulation", c_scope);
        wait for 1 us;
        report_alert_counters(FINAL);

        wait for 1000 ns;
        stop;
    end process p_main;

end architecture bhv;
