
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

        o_busy: out std_logic;
        o_fifo_wmark: out std_logic;

        o_errors: out t_err_bitmap
    );
end entity capture;

architecture behaviour of capture is
    signal r_ccd_rdy: std_logic;
    signal r_ccd_busy: std_logic;
    signal r_ccd_start: std_logic;
    signal r_ccd_data: std_logic_vector(15 downto 0);

    signal r_total_avg_busy: std_logic;
    signal r_total_avg_rdy: std_logic;
    signal r_total_avg_data: std_logic_vector(r_ccd_data'range);

    signal r_moving_avg_rdy: std_logic;
    signal r_moving_avg_data: std_logic_vector(r_ccd_data'range);
    signal r_moving_avg_busy: std_logic;

    signal r_dc_rdy: std_logic;
    signal r_dc_data: std_logic_vector(r_ccd_data'range);
    signal r_dc_busy: std_logic;
    signal r_dc_calib: std_logic;

    signal r_fifo_pl_wmark: std_logic;
    signal r_fifo_raw_wmark: std_logic;

    signal r_fifo_raw_wr: std_logic;
    signal r_fifo_pl_wr: std_logic;

    type t_state is (
        S_IDLE, S_STARTING, S_WAITING, S_RUNNING, S_STOPPING_1,
        S_STOPPING_2, S_STOPPING_3
    );
    signal r_state: t_state;
begin
    r_ccd_start <= '1' when r_state = S_STARTING else '0';
    r_fifo_pl_wr <= r_dc_rdy and not r_dc_calib;
    r_fifo_raw_wr <= r_ccd_rdy and not r_dc_calib;

    u_ccd: entity work.tcd1304(rtl)
        generic map(
            G_CLK_FREQ => 100_000_000,
            G_NUM_ELEMENTS => C_CCD_NUM_ELEMENTS
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
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

            o_busy => r_ccd_busy,
            o_data_rdy => r_ccd_rdy,
            o_data => r_ccd_data
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
            i_data => r_ccd_data,
            i_rd => i_fifo_raw_rd,
            o_data => o_fifo_raw_data,
            o_watermark => r_fifo_raw_wmark,
            o_errors => o_errors
        );

    u_total_avg: entity work.avg_total
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_n => get_reg(i_regmap, REG_TOTAL_AVG_N)(4 downto 0),
            i_data => r_ccd_data,
            i_en => r_ccd_busy,
            i_rdy => r_ccd_rdy,
            o_data => r_total_avg_data,
            o_rdy => r_total_avg_rdy,
            o_busy => r_total_avg_busy
        );

    u_moving_avg: entity work.avg_moving
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_n => get_reg(i_regmap, REG_MOVING_AVG_N),
            i_en => r_total_avg_busy,
            i_rdy => r_total_avg_rdy,
            i_data => r_total_avg_data,
            o_busy => r_moving_avg_busy,
            o_rdy => r_moving_avg_rdy,
            o_data => r_moving_avg_data
        );

    u_dark_current: entity work.dark_current
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_calib => i_dc_calib,
            i_en => r_moving_avg_busy,
            i_rdy => r_moving_avg_rdy,
            i_data => r_moving_avg_data,
            o_rdy => r_dc_rdy,
            o_busy => r_dc_busy,
            o_data => r_dc_data,
            o_errors => o_errors
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
            i_data => r_dc_data,
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
            o_busy <= r_moving_avg_busy;
        else
            o_busy <= r_ccd_busy;
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
                        if r_dc_busy = '1' then
                            r_state <= S_RUNNING;
                        end if;

                    when S_RUNNING =>
                        if r_ccd_busy = '0' then
                            r_state <= S_STOPPING_1;
                        end if;

                    when S_STOPPING_1 =>
                        r_state <= S_STOPPING_2;

                    when S_STOPPING_2 =>
                        r_state <= S_STOPPING_3;

                    -- Delay checking as it may take time for the busy signal
                    -- of the total average stage to fall.
                    when S_STOPPING_3 =>
                        if r_total_avg_busy = '1' then
                            r_state <= S_STARTING;
                        elsif r_dc_busy = '0' then
                            r_state <= S_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process p_state;

end architecture behaviour;
