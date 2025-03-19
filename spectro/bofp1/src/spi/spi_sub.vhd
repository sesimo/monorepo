
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Note that this runs only on the SCLK and does intentionally not cross
-- any clock domains (apart from the asynchronous reset). Users must 
-- pay extra attention to ensure CCD happens safely.
entity spi_sub is
    generic (
        G_DATA_WIDTH: integer := 8
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        
        i_sclk: in std_logic;
        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        
        i_mosi: in std_logic;
        i_cs_n: in std_logic;
        o_miso: out std_logic;

        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_data_shf: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_sample_done: out std_logic;
        o_shift_done: out std_logic
    );
end entity;

architecture rtl of spi_sub is
    signal r_shift_en: std_logic;
    signal r_sample_en: std_logic;

    signal r_sclk_buf: std_logic;
    signal r_sclk_unsafe: std_logic;
    signal r_mosi_buf: std_logic;
    signal r_mosi_unsafe: std_logic;
    signal r_cs_n_buf: std_logic;
    signal r_cs_n_unsafe: std_logic;
begin
    -- Instantiate common enttiy
    u_spi_common: entity work.spi_common
        generic map(
            G_DATA_WIDTH => G_DATA_WIDTH
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,

            i_sample_en => r_sample_en,
            i_shift_en => r_shift_en,

            i_in => i_mosi,
            i_cs_n => r_cs_n_buf,
            o_out => o_miso,

            i_data => i_data,
            o_data => o_data,
            o_data_shf => o_data_shf,

            o_sample_done => o_sample_done,
            o_shift_done => o_shift_done
        );

    -- Cross clock domain. Ensures that the SPI signals are stable before
    -- being processed by the SPI entity
    p_cdc: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_sclk_buf <= r_sclk_unsafe;
            r_mosi_buf <= r_mosi_unsafe;
            r_cs_n_buf <= r_cs_n_unsafe;

            r_sclk_unsafe <= i_sclk;
            r_mosi_unsafe <= i_mosi;
            r_cs_n_unsafe <= i_cs_n;
        end if;
    end process p_cdc;

    -- Detect rising edge, which will be used for shifting
    u_edge_shift: entity work.edge_detect(rtl)
        generic map(
            C_FROM => '0',
            C_TO => '1'
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_sig => r_sclk_buf,
            o_edge => r_shift_en
        );

    -- Detect falling edge, which will be used for sampling
    u_edge_sample: entity work.edge_detect(rtl)
        generic map(
            C_FROM => '1',
            C_TO => '0'
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_sig => r_sclk_buf,
            o_edge => r_sample_en
        );

end architecture;
