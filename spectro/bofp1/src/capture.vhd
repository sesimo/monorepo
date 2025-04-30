
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity capture is
    generic (
        C_CCD_NUM_ELEMENTS: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_regmap: in t_regmap;

        i_adc_eoc: in std_logic;
        o_adc_stconv: out std_logic;
        i_adc_sclk2: in std_logic;
        o_adc_mosi: out std_logic;
        i_adc_miso: in std_logic;
        o_adc_cs_n: out std_logic;

        o_pin_sh: out std_logic;
        o_pin_icg: out std_logic;
        o_pin_mclk: out std_logic;

        i_fifo_raw_rd: in std_logic;
        i_fifo_pl_rd: in std_logic;
        o_fifo_raw_data: out std_logic_vector(15 downto 0);
        o_fifo_pl_data: out std_logic_vector(15 downto 0);

        i_dc_calib: in std_logic;
        i_ccd_flush: in std_logic;

        o_busy: out std_logic;
        o_fifo_wmark: out std_logic;

        o_errors: out t_err_bitmap
    );
end entity capture;

architecture behaviour of capture is
    signal r_ccd_start: std_logic;
    signal r_ccd_rdy_out: std_logic;
    signal r_ccd_busy_out: std_logic;
    signal r_ccd_data_out: std_logic_vector(15 downto 0);

    signal r_total_avg_busy_out: std_logic;
    signal r_total_avg_rdy_out: std_logic;
    signal r_total_avg_data_out: std_logic_vector(r_ccd_data_out'range);
    signal r_total_avg_en: std_logic;

    signal r_moving_avg_rdy_in: std_logic;
    signal r_moving_avg_rdy_out: std_logic;
    signal r_moving_avg_data_in: std_logic_vector(r_ccd_data_out'range);
    signal r_moving_avg_data_out: std_logic_vector(r_ccd_data_out'range);
    signal r_moving_avg_busy_in: std_logic;
    signal r_moving_avg_busy_out: std_logic;

    signal r_dc_rdy_in: std_logic;
    signal r_dc_rdy_out: std_logic;
    signal r_dc_data_in: std_logic_vector(r_ccd_data_out'range);
    signal r_dc_data_out: std_logic_vector(r_ccd_data_out'range);
    signal r_dc_busy_in: std_logic;
    signal r_dc_busy_out: std_logic;
    signal r_dc_calib: std_logic;

    signal r_pl_rdy: std_logic;
    signal r_pl_busy: std_logic;
    signal r_pl_data: std_logic_vector(r_ccd_data_out'range);

    signal r_fifo_pl_wmark: std_logic;
    signal r_fifo_raw_wmark: std_logic;

    signal r_fifo_raw_wr: std_logic;
    signal r_fifo_pl_wr: std_logic;

    type t_state is (
        S_IDLE, S_STARTING, S_WAITING, S_RUNNING,
        S_STOP_WAIT, S_STOPPING
    );
    signal r_state: t_state;

    signal r_stop_buf: std_logic_vector(5 downto 0);
    signal r_stop: std_logic;
begin
    r_ccd_start <= '1' when r_state = S_STARTING else '0';
    r_fifo_pl_wr <= r_pl_rdy and not r_dc_calib;
    r_fifo_raw_wr <= r_ccd_rdy_out and not r_dc_calib;

    u_ccd: entity work.tcd1304(rtl)
        generic map(
            G_CLK_FREQ => 100_000_000,
            G_NUM_ELEMENTS => C_CCD_NUM_ELEMENTS
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_flush => i_ccd_flush,
            i_start => r_ccd_start,
            i_sh_div => get_reg(i_regmap, REG_SHDIV1) &
                        get_reg(i_regmap, REG_SHDIV2) &
                        get_reg(i_regmap, REG_SHDIV3),
            
            i_adc_eoc => i_adc_eoc,
            o_adc_stconv => o_adc_stconv,
            i_adc_sclk2 => i_adc_sclk2,
            o_adc_mosi => o_adc_mosi,
            i_adc_miso => i_adc_miso,
            o_adc_cs_n => o_adc_cs_n,

            o_pin_sh => o_pin_sh,
            o_pin_icg => o_pin_icg,
            o_pin_mclk => o_pin_mclk,

            o_busy => r_ccd_busy_out,
            o_data_rdy => r_ccd_rdy_out,
            o_data => r_ccd_data_out
        );

    u_fifo_raw: entity work.frame_fifo
        generic map(
            C_OVERFLOW => ERR_FIFO_RAW_OVERFLOW,
            C_UNDERFLOW => ERR_FIFO_RAW_UNDERFLOW
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_wr => r_fifo_raw_wr,
            i_data => r_ccd_data_out,
            i_rd => i_fifo_raw_rd,
            o_data => o_fifo_raw_data,
            o_watermark => r_fifo_raw_wmark,
            o_errors => o_errors
        );

    u_total_avg: entity work.avg_total
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_n => get_reg(i_regmap, REG_TOTAL_AVG_N)(3 downto 0),
            i_data => r_ccd_data_out,
            i_en => r_ccd_busy_out,
            i_rdy => r_ccd_rdy_out,
            o_data => r_total_avg_data_out,
            o_rdy => r_total_avg_rdy_out,
            o_busy => r_total_avg_busy_out
        );

    u_totavg_ctrl: entity work.stage_ctrl
        generic map(
            C_FIELD => PRC_TOTAVG_ENA
        )
        port map(
            i_regmap => i_regmap,
            i_rdy_raw => r_ccd_rdy_out,
            i_busy_raw => r_ccd_busy_out,
            i_data_raw => r_ccd_data_out,
            i_rdy_pl => r_total_avg_rdy_out,
            i_busy_pl => r_total_avg_busy_out,
            i_data_pl => r_total_avg_data_out,
            o_rdy => r_moving_avg_rdy_in,
            o_busy => r_moving_avg_busy_in,
            o_data => r_moving_avg_data_in,
            o_en => r_total_avg_en
        );

    u_moving_avg: entity work.avg_moving
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_n => get_reg(i_regmap, REG_MOVING_AVG_N)(3 downto 0),
            i_en => r_moving_avg_busy_in,
            i_rdy => r_moving_avg_rdy_in,
            i_data => r_moving_avg_data_in,
            o_busy => r_moving_avg_busy_out,
            o_rdy => r_moving_avg_rdy_out,
            o_data => r_moving_avg_data_out
        );

    u_movavg_ctrl: entity work.stage_ctrl
        generic map(
            C_FIELD => PRC_MOVAVG_ENA
        )
        port map(
            i_regmap => i_regmap,
            i_rdy_raw => r_moving_avg_rdy_in,
            i_busy_raw => r_moving_avg_busy_in,
            i_data_raw => r_moving_avg_data_in,
            i_rdy_pl => r_moving_avg_rdy_out,
            i_busy_pl => r_moving_avg_busy_out,
            i_data_pl => r_moving_avg_data_out,
            o_rdy => r_dc_rdy_in,
            o_busy => r_dc_busy_in,
            o_data => r_dc_data_in
        );

    u_dark_current: entity work.dark_current
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_calib => i_dc_calib,
            i_en => r_dc_busy_in,
            i_rdy => r_dc_rdy_in,
            i_data => r_dc_data_in,
            o_rdy => r_dc_rdy_out,
            o_busy => r_dc_busy_out,
            o_data => r_dc_data_out,
            o_errors => o_errors
        );

    u_dc_ctrl: entity work.stage_ctrl
        generic map(
            C_FIELD => PRC_DC_ENA
        )
        port map(
            i_regmap => i_regmap,
            i_rdy_raw => r_dc_rdy_in,
            i_busy_raw => r_dc_busy_in,
            i_data_raw => r_dc_data_in,
            i_rdy_pl => r_dc_rdy_out,
            i_busy_pl => r_dc_busy_out,
            i_data_pl => r_dc_data_out,
            o_rdy => r_pl_rdy,
            o_busy => r_pl_busy,
            o_data => r_pl_data
        );

    u_fifo_pl: entity work.frame_fifo
        generic map(
            C_OVERFLOW => ERR_FIFO_PL_OVERFLOW,
            C_UNDERFLOW => ERR_FIFO_PL_UNDERFLOW
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_wr => r_fifo_pl_wr,
            i_data => r_pl_data,
            i_rd => i_fifo_pl_rd,
            o_data => o_fifo_pl_data,
            o_watermark => r_fifo_pl_wmark,
            o_errors => o_errors
        );

    p_fifo_wmark: process(all)
    begin
        if get_prc(i_regmap, PRC_WMARK_SRC) = '1' then
            o_fifo_wmark <= r_fifo_pl_wmark;
        else
            o_fifo_wmark <= r_fifo_raw_wmark;
        end if;
    end process p_fifo_wmark;

    p_busy: process(all)
    begin
        if get_prc(i_regmap, PRC_BUSY_SRC) = '1' then
            o_busy <= r_pl_busy;
        else
            o_busy <= r_ccd_busy_out;
        end if;
    end process p_busy;

    p_calib: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_dc_calib = '1' then
                r_dc_calib <= '1';
            elsif r_state = S_IDLE then
                r_dc_calib <= '0';
            end if;
        end if;
    end process p_calib;

    -- Wait a number of cycles to allow the pipeline to complete before
    -- checking if the total average stage remains active. If it does, we
    -- need to repeat capturing.
    p_stop_wait: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if r_state /= S_STOP_WAIT then
                r_stop_buf <= (others => '0');
            else
                r_stop_buf <= r_stop_buf(r_stop_buf'high-1 downto 0) & '1';
            end if;
        end if;
    end process p_stop_wait;

    r_stop <= r_stop_buf(r_stop_buf'high);

    p_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_IDLE;
            else
                case r_state is
                    when S_IDLE =>
                        if i_dc_calib = '1' or i_start = '1' then
                            r_state <= S_STARTING;
                        end if;

                    when S_STARTING =>
                        r_state <= S_WAITING;

                    when S_WAITING =>
                        if r_pl_busy = '1' then
                            r_state <= S_RUNNING;
                        end if;

                    when S_RUNNING =>
                        if r_ccd_busy_out = '0' then
                            r_state <= S_STOP_WAIT;
                        end if;

                    when S_STOP_WAIT =>
                        if r_stop = '1' then
                            r_state <= S_STOPPING;
                        end if;

                    when S_STOPPING =>
                        if r_total_avg_en = '1' and r_total_avg_busy_out = '1' then
                            r_state <= S_STARTING;
                        elsif r_pl_busy = '0' then
                            r_state <= S_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process p_state;

end architecture behaviour;
