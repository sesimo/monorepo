
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
        G_SCLK_DIV: integer := 13
    );
end entity tb_bofp1;

architecture bhv of tb_bofp1 is
    signal r_clk:  std_logic;
    signal r_rst_n: std_logic := '0';

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
    constant c_reg_shdiv1: std_logic_vector(7 downto 0) := x"84";
    constant c_reg_shdiv2: std_logic_vector(7 downto 0) := x"85";
    constant c_reg_shdiv3: std_logic_vector(7 downto 0) := x"86";
    constant c_reg_prc_ctrl: std_logic_vector(7 downto 0) := x"87";
    constant c_reg_moving_avg_n: std_logic_vector(7 downto 0) := x"88";
    constant c_reg_total_avg_n: std_logic_vector(7 downto 0) := x"89";
    constant c_reg_status: std_logic_vector(7 downto 0) := x"8a";
    constant c_reg_dc_calib: std_logic_vector(15 downto 0) := x"8b00";
    constant c_reg_flush: std_logic_Vector(15 downto 0) := x"8c00";

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
    constant c_sclk_period: time := c_clk_period * G_SCLK_DIV;

    constant c_ccd_pix_count: integer := 368;
    constant c_val_base: integer := 3000;
    constant c_dc_base: integer := 4000;

    constant c_total_avg_n: integer := 5;
    constant c_moving_avg_n: integer := 3;
    constant c_moving_avg_n_sum: integer := c_moving_avg_n * 2 + 1;

    signal r_dc_calib: boolean := false;

    signal r_read_frame_count: integer := 0;
    signal r_ccd_frame_count: integer := 0;

    type t_moving_avg_window is array(c_moving_avg_n_sum-1 downto 0) of unsigned(15 downto 0);

    -- Wait to leave reset
    procedure wait_rst is
    begin
        if r_rst_n = '0' or r_rst_n = 'U' then
            wait until r_rst_n = '1';
        end if;
    end procedure wait_rst;

    function calc_dc_val(clk_count: integer) return integer is
    begin
        return c_dc_base + clk_count;
    end function calc_dc_val;

    procedure inc_clk_count(variable clk_count: inout integer) is
    begin
        clk_count := (clk_count + 1) mod c_ccd_pix_count;
    end procedure inc_clk_count;

    procedure inc_noise_count(variable noise_count: inout integer) is
    begin
        noise_count := (noise_count + 1) mod 10;
    end procedure inc_noise_count;

    procedure calc_val(variable val: out integer;
                       variable clk_count: inout integer;
                       variable noise_count: inout integer) is
        variable dc: integer;
    begin
        dc := calc_dc_val(clk_count);
        val := dc + c_val_base + clk_count + noise_count;

        inc_clk_count(clk_count);
        inc_noise_count(noise_count);
    end procedure calc_val;

    procedure calc_ccd_val(variable val: out integer;
                           variable clk_count: inout integer;
                           variable noise_count: inout integer;
                           constant frame_count: in integer) is
        variable iter_offset: integer;
    begin
        if not r_dc_calib then
            -- Add an offset so that it is easy to calculate the average later
            -- The average should be the same value as the value produced
            -- when iter_offset=0
            iter_offset := -integer(floor(real(c_total_avg_n)/2.0)) + frame_count;

            calc_val(val, clk_count, noise_count);
            val := val + iter_offset;
        else
            val := calc_dc_val(clk_count);
            inc_clk_count(clk_count);
        end if;
    end procedure calc_ccd_val;

    procedure calc_total_avg_val(variable val: out unsigned;
                                 variable clk_count: inout integer;
                                 variable noise_count: inout integer) is
        variable ival: integer;
    begin
        calc_val(ival, clk_count, noise_count);
        val := to_unsigned(ival, val'length);
    end procedure calc_total_avg_val;

    procedure calc_moving_avg_val(variable val: out unsigned;
                                  variable window: inout t_moving_avg_window;
                                  variable next_val: in unsigned) is
        variable sum: unsigned(31 downto 0);
    begin
        window := window(window'high-1 downto 0) & next_val;
        sum := (others => '0');

        for i in 0 to window'high loop
            sum := sum + window(i);
        end loop;

        val := resize(sum / window'length, val'length);
    end procedure calc_moving_avg_val;
begin
    clock_generator(r_clk, r_clkena, c_clk_period, "OSC Main");

    u_dut: entity work.bofp1(structural)
        generic map(
            C_CCD_NUM_ELEMENTS => c_ccd_pix_count
        )
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
                        calc_ccd_val(val, data_cycles, noise_count, r_ccd_frame_count);

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
            r_ccd_frame_count <= (r_ccd_frame_count + 1) mod c_total_avg_n;
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

        variable pl_cycles: integer := 0;
        variable pl_noise: integer := 0;
        variable pl_val: unsigned(15 downto 0);
        variable pl_moving_avg_window: t_moving_avg_window;

        variable dc_moving_avg_window: t_moving_avg_window;

        -- Check the readings from one stream (16 values)
        procedure check_adc_readings(count: integer; offset: integer;
                                     data: std_logic_vector) is
            variable head: integer;
            variable idx: integer;
        begin
            for i in 0 to count-1 loop
                head := data'high - i*16;
                idx := offset + i;

                calc_ccd_val(ccd_val, ccd_cycles, ccd_noise, r_read_frame_count);

                check_value(
                    data(head downto head-15),
                    std_logic_vector(to_unsigned(ccd_val, 16)),
                    "Check ADC reading: " & integer'image(idx)
                );
            end loop;
        end procedure check_adc_readings;

        procedure init_pl_window(variable window: out t_moving_avg_window) is
            variable ret: t_moving_avg_window;
            variable val: unsigned(15 downto 0);
        begin
            for i in 1 to c_moving_avg_n_sum-1 loop
                calc_total_avg_val(val, pl_cycles, pl_noise);
                ret := ret(ret'high-1 downto 0) & val;
            end loop;

            window := ret;
        end procedure init_pl_window;

        procedure init_dc_window(variable window: out t_moving_avg_window) is
            variable ret: t_moving_avg_window;
            variable val: unsigned(15 downto 0);
        begin
            for i in 1 to c_moving_avg_n_sum-1 loop
                val := to_unsigned(32+calc_dc_val(i-1), val'length);
                ret := ret(ret'high-1 downto 0) & val;
            end loop;

            window := ret;
        end procedure init_dc_window;

        -- Check the readings from one stream (16 values)
        procedure check_pl_readings(count: integer; offset: integer;
                                     data: std_logic_vector) is
            variable head: integer;
            variable idx: integer;
            variable dc: unsigned(15 downto 0);
        begin
            for i in 0 to count-1 loop
                head := data'high - i*16;
                idx := offset + i;

                dc := to_unsigned(calc_dc_val(pl_cycles), dc'length);
                calc_moving_avg_val(dc, dc_moving_avg_window, dc);

                calc_total_avg_val(pl_val, pl_cycles, pl_noise);
                calc_moving_avg_val(pl_val, pl_moving_avg_window, pl_val);

                pl_val := pl_val - dc;

                if idx < c_ccd_pix_count - 48 - c_moving_avg_n_sum then
                    -- Because we divide by multiplying, we may sometimes
                    -- be one off. This is good enough.
                    check_value_in_range(
                        to_integer(unsigned(data(head downto head-15))),
                        to_integer(pl_val-1),
                        to_integer(pl_val+1),
                        "Check pipeline reading: " & integer'image(idx)
                    );
                end if;
            end loop;
        end procedure check_pl_readings;

        procedure cmd_sample is
        begin
            spi_master_transmit(
                c_reg_sample,
                "TX sample cmd",
                r_spi_sub_if,
                config => r_spi_conf
            );
        end procedure cmd_sample;

        -- Check values read out from the raw FIFO
        procedure check_fifo_raw_read(constant offset: integer;
                                  constant len: integer) is
            variable rx_data: std_logic_vector(255 downto 0);
            variable tx_data: std_logic_vector(rx_data'range) := (others => '0');
        begin
            -- Prepare stream command
            tx_data(tx_data'high downto tx_data'high-15) := c_reg_stream_raw;

            spi_master_transmit_and_receive(
                tx_data(tx_data'high downto tx_data'length - (len+1) * 16),
                rx_data(rx_data'high downto rx_data'length - (len+1) * 16),
                "FIFO stream raw", r_spi_sub_if,
                config => r_spi_conf
            );

            check_adc_readings(len, offset, rx_data(rx_data'high-16 downto 0));
        end procedure check_fifo_raw_read;

        -- Check values read out from the pipeline FIFO
        procedure check_fifo_pl_read(constant offset: integer;
                                  constant len: integer) is
            variable rx_data: std_logic_vector(255 downto 0);
            variable tx_data: std_logic_vector(rx_data'range) := (others => '0');
        begin
            -- Prepare stream command
            tx_data(tx_data'high downto tx_data'high-15) := c_reg_stream_pl;

            spi_master_transmit_and_receive(
                tx_data(tx_data'high downto tx_data'length - (len+1) * 16),
                rx_data(rx_data'high downto rx_data'length - (len+1) * 16),
                "FIFO stream pipeline", r_spi_sub_if,
                config => r_spi_conf
            );

            check_pl_readings(len, offset, rx_data(rx_data'high-16 downto 0));
        end procedure check_fifo_pl_read;

        procedure set_prc_ctrl(constant pl: boolean) is
            variable tx_data: std_logic_vector(15 downto 0);
            variable rx_data: std_logic_vector(tx_data'range);
            variable pl_cast: std_logic;
        begin
            pl_cast := '1' when pl else '0';
            tx_data(tx_data'high downto tx_data'high-7) := c_reg_prc_ctrl;

            spi_master_transmit_and_receive(
                "0" & tx_data(tx_data'high-1 downto 0),
                rx_data,
                "Get PRC register",
                r_spi_sub_if,
                config => r_spi_conf
            );

            tx_data(7 downto 0) := rx_data(7 downto 0);
            tx_data(0) := pl_cast;
            tx_data(1) := pl_cast;

            spi_master_transmit(
                tx_data,
                "Set wmark src",
                r_spi_sub_if,
                config => r_spi_conf
            );
        end procedure set_prc_ctrl;

        procedure set_moving_avg_n(constant n: integer) is
        begin
            spi_master_transmit(
                std_logic_vector'(
                    c_reg_moving_avg_n & std_logic_vector(to_unsigned(n, 8))),
                "Set moving avg N",
                r_spi_sub_if,
                config => r_spi_conf
            );
        end procedure set_moving_avg_n;

        procedure set_total_avg_n(constant n: integer) is
        begin
            spi_master_transmit(
                std_logic_vector'(
                    c_reg_total_avg_n & std_logic_vector(to_unsigned(n, 8))),
                "Set total avg N",
                r_spi_sub_if,
                config => r_spi_conf
            );
        end procedure set_total_avg_n;

        procedure check_frame(constant read_pl: boolean) is
            variable offset: integer := 0;
            variable count: integer;

            constant cnt_per_read: integer := 256 / 16 - 1;
            constant num_pix: integer := c_ccd_pix_count - 48;
            constant num_iter: integer := num_pix / cnt_per_read;
        begin
            -- Set the watermark and busy source. On the last frame readout, the
            -- watermark source is set to the pipeline FIFO, which comes a
            -- few cycles after the raw FIFO. This way, both the FIFOs
            -- can be read out safely at this watermark.
            set_prc_ctrl(read_pl);

            if r_ccd_busy /= '1' then
                wait until r_ccd_busy = '1';
            end if;

            pl_noise := 32 mod 10;
            pl_cycles := 32;
            init_pl_window(pl_moving_avg_window);

            ccd_cycles := 32;
            ccd_noise := 32 mod 10;

            for i in 0 to num_iter loop
                if r_ccd_busy = '1' then
                    wait until r_fifo_wmark = '1' or r_ccd_busy = '0';
                end if;

                if offset >= num_pix - cnt_per_read then
                    count := num_pix - offset;
                else
                    count := cnt_per_read;
                end if;

                check_fifo_raw_read(offset, count);

                if read_pl then
                    check_fifo_pl_read(offset, count);
                end if;

                offset := offset + count;

                -- Ensure CS is released between
                wait for 1 ps;
            end loop;
        end procedure check_frame;

        procedure do_dc_calib is
        begin
            r_dc_calib <= true;

            init_dc_window(dc_moving_avg_window);

            set_prc_ctrl(true);

            spi_master_transmit(
                c_reg_dc_calib,
                "Do DC calib",
                r_spi_sub_if,
                config => r_spi_conf
            );
            wait until r_ccd_busy = '0';

            r_dc_calib <= false;
        end procedure do_dc_calib;
    begin
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);
        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Simulation setup", c_scope);
        ------------------------------------------------------------------------
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

        spi_master_transmit(
            c_reg_flush,
            "Test flushing",
            r_spi_sub_if,
            config => r_spi_conf
        );
        wait for 2 ms;

        spi_master_transmit(
            x"88010800",
            "Test readout",
            r_spi_sub_if,
            config => r_spi_conf
        );

        set_moving_avg_n(c_moving_avg_n);
        set_total_avg_n(c_total_avg_n);

        do_dc_calib;

        cmd_sample;
        for j in 1 to c_total_avg_n loop
            r_read_frame_count <= r_ccd_frame_count;
            check_frame(j = c_total_avg_n);

            wait for 1 ps;
        end loop;

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
