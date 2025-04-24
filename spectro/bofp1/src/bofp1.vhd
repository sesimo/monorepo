library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.ctrl_common.all;
use work.vivado.all;

entity bofp1 is
    generic (
        C_CCD_NUM_ELEMENTS: integer := 3694
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;

        o_ccd_sh: out std_logic;
        o_ccd_mclk: out std_logic;
        o_ccd_icg: out std_logic;
        o_ccd_busy: out std_logic;

        i_adc_eoc: in std_logic;
        o_adc_stconv: out std_logic;

        o_fifo_wmark: out std_logic;

        i_spi_main_miso: in std_logic;
        o_spi_main_mosi: out std_logic;
        o_spi_main_sclk: out std_logic;
        o_spi_main_cs_n: out std_logic;

        i_spi_sub_sclk: in std_logic;
        i_spi_sub_cs_n: in std_logic;
        i_spi_sub_mosi: in std_logic;
        o_spi_sub_miso: out std_logic
    );
end entity bofp1;

architecture structural of bofp1 is
    signal r_rst: std_logic;
    signal r_rst_n: std_logic;
    signal r_rst_en: std_logic;
    signal r_rst_gen: std_logic;

    signal r_cap_start: std_logic; -- Driven by control module
    signal r_dc_calib: std_logic;
    
    signal r_fifo_pl_rd: std_logic;
    signal r_fifo_raw_rd: std_logic;
    signal r_fifo_pl_data: std_logic_vector(15 downto 0);
    signal r_fifo_raw_data: std_logic_vector(15 downto 0);

    -- Generated clocks
    signal r_adc_sclk2: std_logic;
    signal r_clk_main: std_logic;

    signal r_regmap: t_regmap;
    signal r_errors: t_err_bitmap;
begin
    r_rst_n <= not r_rst;
    r_rst <= '1' when r_rst_gen = '1' or i_rst_n = '0' else '0';

    u_reset: entity work.reset(rtl)
        generic map(
            G_CYC_COUNT => 4
        )
        port map(
            i_clk => r_clk_main,
            i_en => r_rst_en,
            o_rst => r_rst_gen
        );

    u_clk: clk_wizard
        port map(
            clk_in1 => i_clk,
            main => r_clk_main,
            sclk_adc => o_spi_main_sclk,
            sclk2_adc => r_adc_sclk2
        );

    u_capture: entity work.capture
        generic map(
            C_CCD_NUM_ELEMENTS => C_CCD_NUM_ELEMENTS
        )
        port map(
            i_clk => r_clk_main,
            i_rst_n => r_rst_n,
            i_start => r_cap_start,
            i_regmap => r_regmap,

            i_adc_eoc => i_adc_eoc,
            i_adc_sclk2 => r_adc_sclk2,
            i_adc_miso => i_spi_main_miso,
            o_adc_stconv => o_adc_stconv,
            o_adc_mosi => o_spi_main_mosi,
            o_adc_cs_n => o_spi_main_cs_n,

            o_pin_sh => o_ccd_sh,
            o_pin_mclk => o_ccd_mclk,
            o_pin_icg => o_ccd_icg,
            o_busy => o_ccd_busy,

            i_fifo_pl_rd => r_fifo_pl_rd,
            i_fifo_raw_rd => r_fifo_raw_rd,
            o_fifo_pl_data => r_fifo_pl_data,
            o_fifo_raw_data => r_fifo_raw_data,

            i_dc_calib => r_dc_calib,

            o_fifo_wmark => o_fifo_wmark,
            o_errors => r_errors
        );

    u_ctrl: entity work.ctrl(behaviour)
        port map(
            i_clk => r_clk_main,
            i_rst_n => r_rst_n,
            o_ccd_sample => r_cap_start,
            o_rst => r_rst_en,

            i_sclk => i_spi_sub_sclk,
            i_cs_n => i_spi_sub_cs_n,
            i_mosi => i_spi_sub_mosi,
            o_miso => o_spi_sub_miso,

            i_fifo_pl_data => r_fifo_pl_data,
            i_fifo_raw_data => r_fifo_raw_data,
            o_fifo_pl_rd => r_fifo_pl_rd,
            o_fifo_raw_rd => r_fifo_raw_rd,

            o_dc_calib => r_dc_calib,

            i_errors => r_errors,
            io_regmap => r_regmap
        );

end architecture structural;
