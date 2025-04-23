
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity capture is
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

    signal r_fifo_pl_wmark: std_logic;
    signal r_fifo_raw_wmark: std_logic;

    constant c_num_elements: integer := 364;
begin
    r_ccd_start <= i_start;

    u_ccd: entity work.tcd1304(rtl)
        generic map(
            G_CLK_FREQ => 100_000_000,
            G_NUM_ELEMENTS => c_num_elements
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
            i_wr => r_ccd_rdy,
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

    u_fifo_pl: entity work.frame_fifo
        generic map(
            C_OVERFLOW => ERR_FIFO_PL_OVERFLOW,
            C_UNDERFLOW => ERR_FIFO_PL_UNDERFLOW
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_wr => r_moving_avg_rdy,
            i_data => r_moving_avg_data,
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

end architecture behaviour;
