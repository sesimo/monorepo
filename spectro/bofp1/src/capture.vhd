
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity capture is
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_psc_div: in std_logic_vector(7 downto 0);
        i_sh_div: in std_logic_vector(7 downto 0);

        i_adc_eoc: in std_logic;
        o_adc_stconv: out std_logic;
        i_adc_sclk2: in std_logic;
        o_adc_mosi: out std_logic;
        i_adc_miso: in std_logic;
        o_adc_cs_n: out std_logic;

        o_pin_sh: out std_logic;
        o_pin_icg: out std_logic;
        o_pin_mclk: out std_logic;
        o_ccd_busy: out std_logic;

        o_data_rdy: out std_logic;
        o_data: out std_logic_vector(15 downto 0)
    );
end entity capture;

architecture behaviour of capture is
    signal r_ccd_rdy: std_logic;
    signal r_ccd_busy: std_logic;
    signal r_ccd_start: std_logic;
    signal r_ccd_data: std_logic_vector(15 downto 0);
begin
    r_ccd_start <= i_start;

    u_ccd: entity work.tcd1304(rtl)
        generic map(
            G_CLK_FREQ => 100_000_000
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_start => r_ccd_start,
            i_psc_div => i_psc_div,
            i_sh_div => i_sh_div,
            
            i_adc_eoc => i_adc_eoc,
            o_adc_stconv => o_adc_stconv,
            i_adc_sclk2 => i_adc_sclk2,
            o_adc_mosi => o_adc_mosi,
            i_adc_miso => i_adc_miso,
            o_adc_cs_n => o_adc_cs_n,

            o_pin_sh => o_pin_sh,
            o_pin_icg => o_pin_icg,
            o_pin_mclk => o_pin_mclk,

            o_ccd_busy => r_ccd_busy,
            o_data_rdy => r_ccd_rdy,
            o_data => r_ccd_data
        );

    o_ccd_busy <= r_ccd_busy;
    o_data_rdy <= r_ccd_rdy;
    o_data <= r_ccd_data;

end architecture behaviour;
