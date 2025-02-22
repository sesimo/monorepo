
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_spi;
use bitvis_vip_spi.spi_bfm_pkg.all;

entity tb_spi_sub is
    generic (
        G_DATA_WIDTH: integer := 16;
        G_CLK_FREQ: integer := 25_000_000
    );
end entity tb_spi_sub;

architecture bhv of tb_spi_sub is
    signal r_wr_data: std_logic_vector(G_DATA_WIDTH-1 downto 0) := x"ABC0";
    signal r_rd_data: std_logic_vector(G_DATA_WIDTH-1 downto 0);

    signal r_rdy: std_logic;

    -- Bitvis SPI BFM
    signal r_spi_if: t_spi_if;
    signal r_spi_conf: t_spi_bfm_config := C_SPI_BFM_CONFIG_DEFAULT;

    -- UVVM scope
    constant c_scope: string := C_TB_SCOPE_DEFAULT;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
begin
    -- Instantiate SPI entity
    u_spi: entity work.spi_sub(rtl) generic map(
        G_MODE => 1,
        G_DATA_WIDTH => G_DATA_WIDTH
    )
    port map(
        i_sclk => r_spi_if.sclk,
        i_data => r_wr_data,

        i_mosi => r_spi_if.mosi,
        i_cs_n => r_spi_if.ss_n,
        o_miso => r_spi_if.miso,

        o_data => r_rd_data,
        o_sample_done => r_rdy
    );

    p_recv_reg: process
    begin
        wait until r_rdy = '1';
        wait for 1 ps;

        log(ID_LOG_HDR, to_string(r_rd_data), c_scope);

        case r_rd_data is
            when x"3FAB" =>
                r_wr_data <= x"DEA3";
                
            when x"0000" =>
                null;

            when others =>
                r_wr_data <= x"ABC0";
        end case;
    end process p_recv_reg;

    p_main: process
        variable v_data: std_logic_vector(15 downto 0);
        variable v_data32: std_logic_vector(31 downto 0);
    begin
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);
        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Simulation setup", c_scope);
        ------------------------------------------------------------------------
        r_spi_conf.CPOL <= '0';
        r_spi_conf.CPHA <= '1';
        r_spi_conf.spi_bit_time <= c_clk_period;
        r_spi_conf.ss_n_to_sclk <= 200 ns;

        r_spi_if <= init_spi_if_signals(
            config => r_spi_conf,
            master_mode => true
        );
        wait for 1 ps;

        log(ID_LOG_HDR, "Start simulation SPI sub", c_scope);
        log(ID_LOG_HDR, "Bit time: " & time'image(r_spi_conf.spi_bit_time), c_scope);
        ------------------------------------------------------------------------

        -- Check that the SPI implementation returns the correct result
        spi_master_transmit_and_receive(
            x"1BEA",
            v_data,
            "TX unknown, generic response",
            r_spi_if,
            config => r_spi_conf
        );
        check_value(v_data, x"ABC0", ERROR, "Transmit,receive check");

        spi_master_transmit_and_receive(
            x"3FAB" & x"0000",
            v_data32,
            "TX known, special response",
            r_spi_if,
            config => r_spi_conf
        );
        check_value(
            v_data32(15 downto 0), x"DEA3", ERROR,
            "Received response of TX of known sequence"
        );

        -- End simulation
        ------------------------------------------------------------------------
        log(ID_LOG_HDR, "End simulation SPI sub", c_scope);
        wait for 1 us;
        report_alert_counters(FINAL);

        wait for 1000 ns;

        stop;
    end process p_main;
end architecture;
