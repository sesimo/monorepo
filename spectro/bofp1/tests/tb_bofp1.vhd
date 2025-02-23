
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_spi;
use bitvis_vip_spi.spi_bfm_pkg.all;


entity tb_bofp1 is
    generic (
        G_CLK_FREQ: integer := 100_000_000;
        G_CFG_WIDTH: integer := 12; -- Width of config entries,
        G_ADC_WIDTH: integer := 16; -- Width/resoluton of ADC readouts
        G_CTRL_WIDTH: integer := 16; -- Width of ctrl codes

        G_SCLK_DIV: integer := 2
    );
end entity tb_bofp1;

architecture bhv of tb_bofp1 is
    signal r_clk:  std_logic;
    signal r_rst:  std_logic := '1';

    signal r_ccd_sh:  std_logic;
    signal r_ccd_mclk:  std_logic;
    signal r_ccd_icg:  std_logic;

    signal r_adc_eoc:  std_logic;
    signal r_adc_stconv:  std_logic;

    signal r_clkena: boolean;

    signal r_fifo_wmark: std_logic;

    signal r_spi_main_if: t_spi_if;
    signal r_spi_sub_if: t_spi_if;
    signal r_spi_conf: t_spi_bfm_config := C_SPI_BFM_CONFIG_DEFAULT;

    constant c_scope: string := C_TB_SCOPE_DEFAULT;

    constant c_reg_stream: std_logic_vector(15 downto 0) := x"0000";
    constant c_reg_sample: std_logic_vector(15 downto 0) := x"1" & x"000";

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
    constant c_sclk_period: time := c_clk_period * G_SCLK_DIV;
begin
    clock_generator(r_clk, r_clkena, c_clk_period, "OSC Main");

    u_dut: entity work.bofp1(structural)
        generic map(
            G_CFG_WIDTH => G_CFG_WIDTH,
            G_ADC_WIDTH => G_ADC_WIDTH,
            G_CTRL_WIDTH => G_CTRL_WIDTH
        )
        port map(
            i_clk => r_clk,
            i_rst => r_rst,
            
            o_ccd_sh => r_ccd_sh,
            o_ccd_mclk => r_ccd_mclk,
            o_ccd_icg => r_ccd_icg,

            i_adc_eoc => r_adc_eoc,
            o_adc_stconv => r_adc_stconv,

            o_fifo_wmark => r_fifo_wmark,

            i_spi_main_miso => r_spi_main_if.miso,
            o_spi_main_mosi => r_spi_main_if.mosi,
            o_spi_main_sclk => r_spi_main_if.sclk,
            o_spi_main_cs_n => r_spi_main_if.ss_n,

            i_spi_sub_sclk => r_spi_sub_if.sclk,
            i_spi_sub_cs_n => r_spi_sub_if.ss_n,
            i_spi_sub_mosi => r_spi_sub_if.mosi,
            o_spi_sub_miso => r_spi_sub_if.miso
        );

    p_adc: process
    begin
        r_adc_eoc <= '0';
        if r_rst = '1' then
            wait until r_rst = '0';
        end if;

        wait until r_adc_stconv = '1';
        wait for 800 ns;

        r_adc_eoc <= '1';
        wait for 100 ns;
    end process p_adc;

    p_adc_spi: process
        variable v_value: unsigned(15 downto 0) := (others => '0');
    begin
        if r_rst = '1' then
            r_spi_main_if <= init_spi_if_signals(
                config => r_spi_conf,
                master_mode => false
            );
            wait until r_rst = '0';
        end if;

        spi_slave_transmit(
            std_logic_vector(v_value),
            "ADC SPI dummy value",
            r_spi_main_if,
            config=>r_spi_conf
        );

        v_value := v_value + 1;
    end process p_adc_spi;

    p_main: process
        procedure release_reset is
        begin
            r_rst <= '0';
        end procedure release_reset;

        procedure check_adc_readings(
            count: integer;
            offset: integer;
            data: std_logic_vector) is
            variable v_head: integer;
            variable v_value: integer;
        begin
            for i in 0 to count-1 loop
                v_head := data'high - i*16;
                v_value := offset * count + i;

                check_value(
                    data(v_head downto v_head-15),
                    std_logic_vector(to_unsigned(v_value, 16)),
                    "Check ADC reading: " & integer'image(v_value)
                );
            end loop;
        end procedure check_adc_readings;

        variable v_data: std_logic_vector(271 downto 0) := (others => '0');
        variable v_data_tx: std_logic_vector(v_data'range) := (others => '0');
    begin
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);
        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Simulation setup", c_scope);
        ------------------------------------------------------------------------
        r_spi_conf.CPOL <= '0';
        r_spi_conf.CPHA <= '1';
        r_spi_conf.spi_bit_time <= c_sclk_period;

        r_spi_sub_if <= init_spi_if_signals(
            config => r_spi_conf,
            master_mode => true
        );
        r_clkena <= true;

        wait for 10 ns;

        log(ID_LOG_HDR, "Start simulation SPI main", c_scope);
        log(ID_LOG_HDR, "Bit time: " & time'image(r_spi_conf.spi_bit_time), c_scope);
        ------------------------------------------------------------------------
        release_reset;
        wait for 1 ps;

        spi_master_transmit(
            c_reg_sample,
            "TX sample cmd",
            r_spi_sub_if,
            config => r_spi_conf
        );

        for i in 0 to 254 loop
            if i /= 254 then
                wait until r_fifo_wmark = '1';
            else
                wait until r_ccd_icg = '0';
            end if;
            v_data_tx(v_data_tx'high downto v_data_tx'high-15) := c_reg_stream;

            spi_master_transmit_and_receive(
                v_data_tx,
                v_data,
                "TX stream cmd",
                r_spi_sub_if,
                config => r_spi_conf
            );

            check_adc_readings(16, i, v_data(v_data'high - 16 downto 0));
        end loop;

        -- End simulation
        ------------------------------------------------------------------------
        log(ID_LOG_HDR, "End simulation SPI main", c_scope);
        wait for 1 us;
        report_alert_counters(FINAL);

        wait for 1000 ns;
        stop;
    end process p_main;

end architecture bhv;
