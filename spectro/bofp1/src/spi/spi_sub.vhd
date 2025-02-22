
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Note that this runs only on the SCLK and does intentionally not cross
-- any clock domains (apart from the asynchronous reset). Users must 
-- pay extra attention to ensure CCD happens safely.
entity spi_sub is
    generic (
        G_MODE: integer range 0 to 3 := 1;
        G_DATA_WIDTH: integer := 8
    );
    port (
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
begin

    -- Instantiate common enttiy
    u_spi_common: entity work.spi_common
        generic map(
            G_MODE => G_MODE,
            G_DATA_WIDTH => G_DATA_WIDTH
        )
        port map(
            i_sclk => i_sclk,
            i_in => i_mosi,
            o_out => o_miso,
            i_cs_n => i_cs_n,

            i_data => i_data,
            o_data => o_data,
            o_data_shf => o_data_shf,

            o_sample_done => o_sample_done,
            o_shift_done => o_shift_done
        );

end architecture;
