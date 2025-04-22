
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
        G_SCLK_DIV: integer := 7
    );
end entity tb_bofp1;

architecture bhv of tb_bofp1 is
    signal r_clk:  std_logic;
    signal r_rst_n: std_logic;

    signal r_ccd_sh:  std_logic;
    signal r_ccd_mclk:  std_logic;
    signal r_ccd_icg:  std_logic;
    signal r_ccd_busy:  std_logic;

    signal r_adc_eoc:  std_logic;
    signal r_adc_stconv:  std_logic;

    signal r_clkena: boolean;

    signal r_fifo_wmark: std_logic;

    signal r_spi_main_if: t_spi_if;
    signal r_spi_sub_if: t_spi_if;
    signal r_spi_conf: t_spi_bfm_config := C_SPI_BFM_CONFIG_DEFAULT;

    constant c_scope: string := C_TB_SCOPE_DEFAULT;

    constant c_reg_stream_raw: std_logic_vector(15 downto 0) := x"0000";
    constant c_reg_stream_pl: std_logic_vector(15 downto 0) := x"0100";
    constant c_reg_sample: std_logic_vector(15 downto 0) := x"8200";
    constant c_reg_reset: std_logic_vector(15 downto 0) := x"8300";
    constant c_reg_pscdiv: std_logic_vector(7 downto 0) := x"84";
    constant c_reg_shdiv: std_logic_vector(7 downto 0) := x"85";

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
    constant c_sclk_period: time := c_clk_period * G_SCLK_DIV;

    constant c_ccd_pix_count: integer := 3694;

    -- Wait to leave reset
    procedure wait_rst is
    begin
        if r_rst_n = '0' or r_rst_n = 'U' then
            wait until r_rst_n = '1';
        end if;
    end procedure wait_rst;

    procedure calc_ccd_val(variable val: out integer;
                       variable clk_count: inout integer;
                       variable noise_count: inout integer) is
    begin
        val := clk_count + noise_count;
        clk_count := (clk_count + 1) mod c_ccd_pix_count;
        noise_count := (noise_count + 1) mod 10;
    end procedure calc_ccd_val;
begin
    clock_generator(r_clk, r_clkena, c_clk_period, "OSC Main");

    u_dut: entity work.bofp1(structural)
        port map(
            i_clk => r_clk,
            i_rst_n => r_rst_n,
            
            o_ccd_sh => r_ccd_sh,
            o_ccd_mclk => r_ccd_mclk,
            o_ccd_icg => r_ccd_icg,
            o_ccd_busy => r_ccd_busy,

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

    -- ADC and CCD emulation
    b_emul: block
        signal r_dummy_val: unsigned(15 downto 0) := (others => '0');
        signal r_adc_val: unsigned(r_dummy_val'range);
        signal r_adc_rst: boolean := false;

        signal r_ccd_running: boolean := false;
        signal r_ccd_done: boolean := false;

        -- Roughly 25 MHz
        constant c_adc_clk_per: time := c_clk_period * 4;
    begin

        -- Emulate readout values
        p_ccd_data: process(r_ccd_mclk)
            variable mclk_count: integer range 0 to 3 := 0;

            variable data_cycles: integer range 0 to c_ccd_pix_count := 0;
            variable noise_count: integer range 0 to 10 := 0;
            variable val: integer := 0;
        begin
            if rising_edge(r_ccd_mclk) then
                if r_ccd_running then
                    if mclk_count = 0 then
                        calc_ccd_val(val, data_cycles, noise_count);

                        r_dummy_val <= to_unsigned(val, r_dummy_val'length);
                        r_ccd_done <= data_cycles = 0;
                    end if;

                    mclk_count := (mclk_count + 1) mod 4;
                else
                    r_dummy_val <= (others => '0');
                    noise_count := 0;
                    mclk_count := 0;
                end if;
            end if;
        end process p_ccd_data;

        -- Handle ICG signal and begin reading out
        p_ccd_start: process
            variable start: time;
        begin
            wait_rst;

            wait until r_ccd_icg = '1';
            start := now;
            wait until r_ccd_icg = '0';

            check_value_in_range(now - start, 1000 ns, 2500 ns, "ICG pulse");

            r_ccd_running <= true;
            wait until r_ccd_done;
            r_ccd_running <= false;
        end process p_ccd_start;

        -- Handle STconv for the ADC and generate EOC along with making data
        -- ready for the SPI transfer.
        p_conv: process
            variable wait_time: time;
            variable start: time;
            variable time_diff: time;
        begin
            wait_rst;

            wait until r_adc_stconv = '1';
            start := now;

            -- Wait for ADC to 'detect' start signal
            wait for c_adc_clk_per;
            r_adc_eoc <= '0';
        
            -- Ideally this would be after the wait period, but because we
            -- need to wait on STconv in the SPI process in order to receive
            -- reset command, the value must already be loaded at that point.
            r_adc_val <= r_dummy_val;

            -- Wait for STconv to be released so that we can check
            -- duration of the pulse signal. Datasheet specifies that this
            -- must be held for at least 40 ns.
            wait_time := c_adc_clk_per * 18;
            wait until r_adc_stconv = '0' or r_adc_rst;

            if r_adc_rst then
                wait for c_adc_clk_per;
                check_value(r_adc_stconv, '1', "STconv must remain high during reset");
            else
                -- How long was STconv held?
                time_diff := now - start;
                check_value(r_adc_stconv, '0', "STconv pulse value");
                check_value_in_range(time_diff, 40 ns, wait_time, "STconv pulse len");

                -- Typically takes 18 CCLK cycles to convert. Since we have
                -- already waited for a while, subtract that time.
                wait for wait_time - time_diff;
            end if;

            r_adc_eoc <= '1';
        end process p_conv;

        -- Handle SPI access to the ADC
        p_spi: process
            variable rd_data: std_logic_vector(15 downto 0);
            variable init_done: boolean := false;
        begin
            wait_rst;

            if not init_done then
                r_spi_main_if <= init_spi_if_signals(
                    config => r_spi_conf,
                    master_mode => false
                );

                init_done := true;
            end if;

            -- Wait for EOC to be cleared, which means the ADC emulator has
            -- receieved the STconv signal.
            wait until r_adc_eoc = '0';
            wait for 1 ps;

            spi_slave_transmit_and_receive(
                std_logic_vector(r_adc_val),
                rd_data,
                "ADC SPI transaction",
                r_spi_main_if,
                config=>r_spi_conf
            );

            case rd_data(rd_data'high downto rd_data'high-3) is
                when x"D" => null;
                    -- Readout
                    check_value(r_adc_eoc, '1', "EOC must be high when reading");

                when x"E" =>
                    -- Write CFR
                    if rd_data(0) = '0' then
                        check_value(r_adc_stconv, '1',
                            "STconv must be high when entering reset");
                        r_adc_rst <= true;
                        wait for c_adc_clk_per;
                        r_adc_rst <= false;
                    end if;


                when others => error("Invalid command " & to_hstring(rd_data));
            end case;

        end process p_spi;

    end block b_emul;

    p_main: process
        variable ccd_cycles: integer := 0;
        variable ccd_noise: integer := 0;
        variable ccd_val: integer;

        -- Check the readings from one stream (16 values)
        procedure check_adc_readings(count: integer; offset: integer;
                                     data: std_logic_vector) is
            variable head: integer;
            variable idx: integer;
        begin
            for i in 0 to count-1 loop
                head := data'high - i*16;
                idx := offset + i;

                calc_ccd_val(ccd_val, ccd_cycles, ccd_noise);

                check_value(
                    data(head downto head-15),
                    std_logic_vector(to_unsigned(ccd_val, 16)),
                    "Check ADC reading: " & integer'image(idx)
                );
            end loop;
        end procedure check_adc_readings;

        procedure cmd_sample is
        begin
            spi_master_transmit(
                c_reg_sample,
                "TX sample cmd",
                r_spi_sub_if,
                config => r_spi_conf
            );
        end procedure cmd_sample;

        procedure check_fifo_read(constant offset: integer;
                                  constant len: integer) is
            variable rx_data: std_logic_vector(255 downto 0);
            variable tx_data: std_logic_vector(rx_data'range) := (others => '0');
        begin
            -- Prepare stream command
            tx_data(tx_data'high downto tx_data'high-15) := c_reg_stream_raw;

            spi_master_transmit_and_receive(
                tx_data, rx_data, "FIFO stream", r_spi_sub_if,
                config => r_spi_conf
            );

            check_adc_readings(len, offset, rx_data(rx_data'high-16 downto 0));
        end procedure check_fifo_read;

        procedure check_frame is
            variable offset: integer := 0;
            variable count: integer;

            constant cnt_per_read: integer := 256 / 16 - 1;
        begin
            cmd_sample;
            wait until r_ccd_busy = '1';

            for i in 0 to c_ccd_pix_count / cnt_per_read loop
                if r_ccd_busy = '1' then
                    wait until r_fifo_wmark = '1' or r_ccd_busy = '0';
                end if;

                if offset >= c_ccd_pix_count - cnt_per_read then
                    count := c_ccd_pix_count - offset;
                else
                    if r_ccd_busy = '0' then
                        error("Busy fell before reading all");
                    end if;

                    count := cnt_per_read;
                end if;

                check_fifo_read(offset, count);
                offset := offset + count;

                -- Ensure CS is released between
                wait for 1 ps;
            end loop;

            ccd_cycles := 0;
            ccd_noise := 0;
            wait for 1 ps;
        end procedure check_frame;
    begin
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);
        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Simulation setup", c_scope);
        ------------------------------------------------------------------------
        r_rst_n <= '0';

        -- Setup SPI
        r_spi_conf.CPOL <= '0';
        r_spi_conf.CPHA <= '1';
        r_spi_conf.spi_bit_time <= c_sclk_period;
        r_spi_conf.ss_n_to_sclk <= 4 * c_clk_period;
        r_spi_conf.sclk_to_ss_n <= 4 * c_clk_period;
        r_spi_conf.inter_word_delay <= c_clk_period;

        r_spi_sub_if <= init_spi_if_signals(
            config => r_spi_conf,
            master_mode => true
        );
        r_clkena <= true;

        wait for 5 ns;

        log(ID_LOG_HDR, "Start simulation SPI main", c_scope);
        log(ID_LOG_HDR, "Bit time: " & time'image(r_spi_conf.spi_bit_time), c_scope);
        ------------------------------------------------------------------------
        r_rst_n <= '1';
        wait for 1 ps;

        for j in 0 to 1 loop
            check_frame;
        end loop;
        
        spi_master_transmit(
            std_logic_vector'(c_reg_pscdiv & x"f3"),
            "Update pscdiv",
            r_spi_sub_if,
            config => r_spi_conf
        );
        
        spi_master_transmit(
            std_logic_vector'(c_reg_shdiv & x"34"),
            "Update shdiv",
            r_spi_sub_if,
            config => r_spi_conf
        );

        spi_master_transmit(
            c_reg_reset,
            "Reset",
            r_spi_sub_if,
            config => r_spi_conf
        );

        wait for 5 us;

        -- End simulation
        ------------------------------------------------------------------------
        log(ID_LOG_HDR, "End simulation SPI main", c_scope);
        wait for 1 us;
        report_alert_counters(FINAL);

        wait for 1000 ns;
        stop;
    end process p_main;

end architecture bhv;
