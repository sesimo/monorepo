
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
    signal r_sample: std_logic;
    signal r_shift: std_logic;
    
    signal r_arst_n: std_logic;

    -- TODO: Move to common package
    -- Convert a boolean to std_logic '1' or '0'
    function f_bool_logic(b: in boolean) return std_logic is
    begin
        if b then
            return '1';
        end if;

        return '0';
    end function f_bool_logic;

    -- Sample on rising edge (mode 0 and 3, CPHA != CPOL)
    constant c_smpl_ris: std_logic := f_bool_logic(G_MODE = 0 or G_MODE = 3);
begin
    r_sample <= f_bool_logic(i_cs_n = '0' and i_sclk = c_smpl_ris);
    r_shift <= f_bool_logic(i_cs_n = '0' and i_sclk /= c_smpl_ris);

    -- Asynchronouos assertion of reset, synchronous release
    p_reset: process(i_sclk, i_arst_n)
    begin
        if i_arst_n = '0' then
            r_arst_n <= '0';
        elsif rising_edge(i_sclk) then
            r_arst_n <= '1';
        end if;
    end process p_reset;

    -- Read data from MOSI into o_data
    p_sample: process(i_sclk, r_arst_n)
        variable v_count: integer;
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    begin
        if r_arst_n = '0' then
            v_count := 0;
            v_shf_buf := (others => 'X');
            o_data <= (others => 'X');
            o_rdy <= '0';
        elsif i_sclk'event then
            o_rdy <= '0';

            if r_sample = '1' then
                v_count := v_count + 1;
                v_shf_buf := i_mosi & v_shf_buf(v_shf_buf'high downto 1);

                if v_count = G_DATA_WIDTH then
                    v_count := 0;
                    o_data <= v_shf_buf;
                    o_rdy <= '1';
                end if;
            end if;
        end if;
    end process p_sample;

    -- Shift bits in i_data onto MISO
    p_shift: process(i_sclk, r_arst_n)
        variable v_count: integer;
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    begin
        if r_arst_n = '0' then
            o_miso <= 'Z';

            v_count := 0;
            v_shf_buf := (others => 'Z');
        elsif i_sclk'event and r_shift = '1' then
            if v_count = 0 then
                v_shf_buf := i_data;
            end if;

            v_count := v_count + 1;

            o_miso <= v_shf_buf(0);
            v_shf_buf := "Z" & v_shf_buf(v_shf_buf'high downto 1);

            if v_count >= G_DATA_WIDTH then
                v_count := 0;
            end if;
        end if;
    end process p_shift;
end architecture;
