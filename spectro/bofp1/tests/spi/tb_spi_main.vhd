
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_spi;
use bitvis_vip_spi.spi_bfm_pkg.all;

entity tb_spi_main is
    generic (
        G_DATA_WIDTH: integer := 16;
        G_CLK_FREQ: integer := 100_000_000
    );
end entity tb_spi_main;

architecture bhv of tb_spi_main is
    signal r_clk: std_logic := '1';
    signal r_rst_n: std_logic := '0';
    signal r_start: std_logic := '0';
    signal r_wr_data: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_rd_data: std_logic_vector(G_DATA_WIDTH-1 downto 0);

    signal r_clkena: boolean;
    
    signal r_rdy: std_logic;

    -- Bitvis SPI BFM
    signal r_spi_if: t_spi_if;
    signal r_spi_conf: t_spi_bfm_config := C_SPI_BFM_CONFIG_DEFAULT;

    -- UVVM scope
    constant c_scope: string := C_TB_SCOPE_DEFAULT;

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
begin
    clock_generator(r_clk, r_clkena, c_clk_period, "TB CLK");

    -- Instantiation of SPI entity
    u_spi: entity work.spi_main(rtl) generic map(
        G_MODE => 1,
        G_CLK_DIV => 6,
        G_DATA_WIDTH => G_DATA_WIDTH
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_start => r_start,
        i_data => r_wr_data,

        i_miso => r_spi_if.miso,
        o_sclk => r_spi_if.sclk,
        o_mosi => r_spi_if.mosi,
        o_cs_n => r_spi_if.ss_n,

        o_data => r_rd_data,
        o_rdy => r_rdy
    );

    p_main: process
        procedure release_reset is
        begin
            r_rst_n <= '1';
        end procedure release_reset;

        procedure write_read(
            constant din: in std_logic_vector(15 downto 0)) is
        begin
            r_wr_data <= din;
            r_start <= '1';
            wait for c_clk_period;
            r_start <= '0';
        end procedure write_read;

        variable v_data: std_logic_vector(15 downto 0);
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
        r_spi_conf.sclk_to_ss_n <= 2000 ns;

        r_spi_if <= init_spi_if_signals(
            config => r_spi_conf,
            master_mode => false
        );
        wait for 1 ps;
        
        r_clkena <= true;
        wait for 10 ns;

        log(ID_LOG_HDR, "Start simulation SPI main", c_scope);
        log(ID_LOG_HDR, "Bit time: " & time'image(r_spi_conf.spi_bit_time), c_scope);
        ------------------------------------------------------------------------
        release_reset;
        wait for 10 ns;

        write_read(x"ABCD");

        spi_slave_transmit_and_receive(
            x"1234",
            v_data,
            "Transmit,receive",
            r_spi_if,
            config => r_spi_conf
        );

        check_value(r_rd_data, x"1234", ERROR, "Data receieved from slave");
        check_value(v_data, x"ABCD", ERROR, "Data received on slave");

        -- End simulation
        ------------------------------------------------------------------------
        log(ID_LOG_HDR, "End simulation SPI main", c_scope);
        wait for 1 us;
        report_alert_counters(FINAL);

        wait for 1000 ns;
        stop;
    end process p_main;
end architecture;
