
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
        i_cs: in std_logic;
        o_miso: out std_logic;

        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    );
end entity;

architecture rtl of spi_sub is
    signal r_sample: std_logic = '1';
    signal r_shift: std_logic = '1';

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
    constant c_smpl_ris: boolean := f_bool_logic(G_MODE = 0 or G_MODE = 3);
begin
    r_sample <= f_bool_logic(i_cs = '0' and i_sclk = c_smpl_ris);
    r_shift <= f_bool_logic(i_cs = '0' and i_sclk /= c_smpl_ris);

    p_sample: process(i_sclk, i_arst_n)
        variable v_count: integer;
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    begin
        if i_arst_n = '0' then
            v_count := 0;
            v_shf_buf := (others => 'X');
            o_data <= (others => 'X');
        elsif i_sclk'event and r_sample then
            v_count := v_count + 1;
            v_shf_buf := i_mosi & v_shf_buf(v_shf_buf'high downto 1);

            if v_count := G_DATA_WIDTH then
                v_count := 0;
                o_data <= v_shf_buf;
            end if;
        end if;
    end process p_sample;

    p_shift: process(i_sclk, i_arst_n)
        variable v_count: integer;
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    begin
        if i_arst_n = '0' then
            o_miso <= 'Z';

            v_count := 0;
            v_shf_buf := (others => 'Z');
        elsif i_sclk'event and r_shift then
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
