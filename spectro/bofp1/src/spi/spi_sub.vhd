
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
        i_arst_n: in std_logic; 
        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        
        i_mosi: in std_logic;
        i_cs_n: in std_logic;
        o_miso: out std_logic;

        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rdy: out std_logic
    );
end entity;

architecture rtl of spi_sub is
    signal r_arst: boolean;

    -- Sample on rising edge (mode 0 and 3, CPHA != CPOL)
    constant c_smpl_ris: boolean := G_MODE = 0 or G_MODE = 3;
begin
    -- When a reset occurs, assert it asynchronously but release it
    -- synchronously with the CS line. This should give some safety
    -- as SCLK is assumed to arrive slightly later than CS line. The reason
    -- SCLK is not used to release the reset is because the first edge
    -- of the SCLK must be used for the transmission -- which means that
    -- in order to wait for a reset to be released, we would miss the
    -- first cycle.
    r_arst <= (i_arst_n = '0' or r_arst) and i_cs_n /= '0';

    -- Read data from MOSI into o_data
    p_sample: process(i_sclk, r_arst)
        variable v_count: integer;
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);

        -- Check whether we should sample or not. This is done when the
        -- clk is at the edge configured by the SPI mode
        impure function should_sample(signal clk: std_logic) return boolean is
            variable v_edge: boolean;
        begin
            if c_smpl_ris then
                v_edge := rising_edge(clk);
            else
                v_edge := falling_edge(clk);
            end if;

            return i_cs_n = '0' and v_edge;
        end function;
    begin
        if r_arst then
            v_count := 0;
            v_shf_buf := (others => 'X');
            o_data <= (others => 'X');
            o_rdy <= '0';
        elsif should_sample(i_sclk) then
            o_rdy <= '0';

            v_count := v_count + 1;
            v_shf_buf := v_shf_buf(v_shf_buf'high-1 downto 0) & i_mosi;

            if v_count >= G_DATA_WIDTH then
                v_count := 0;
                o_data <= v_shf_buf;
                o_rdy <= '1';
            end if;
        end if;
    end process p_sample;

    -- Shift bits in i_data onto MISO
    p_shift: process(i_sclk, r_arst)
        variable v_count: integer;
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);

        -- Check whether we should shift or not. This is done when the
        -- clk is at the edge configured by the SPI mode
        impure function should_shift(signal clk: std_logic) return boolean is
            variable v_edge: boolean;
        begin
            if c_smpl_ris then
                v_edge := falling_edge(clk);
            else
                v_edge := rising_edge(clk);
            end if;

            return i_cs_n = '0' and v_edge;

        end function;
    begin
        if r_arst then
            o_miso <= 'Z';

            v_count := 0;
            v_shf_buf := (others => 'Z');
        elsif should_shift(i_sclk) then
            if v_count = 0 then
                v_shf_buf := i_data;
            end if;

            v_count := v_count + 1;

            o_miso <= v_shf_buf(v_shf_buf'high);
            v_shf_buf := v_shf_buf(v_shf_buf'high-1 downto 0) & "Z";

            if v_count >= G_DATA_WIDTH then
                v_count := 0;
            end if;
        end if;
    end process p_shift;
end architecture;
