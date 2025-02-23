
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

-- SPI entity working in Mode 1 (CPOL=0,CPHA=1)
entity spi_common is
    generic (
        G_DATA_WIDTH: integer
    );
    port (
        i_sclk: in std_logic;
        i_cs_n: in std_logic;
        i_in: in std_logic;
        o_out: out std_logic;

        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_data_shf: out std_logic_vector(G_DATA_WIDTH-1 downto 0);

        o_sample_done: inout std_logic;
        o_shift_done: inout std_logic
    );
end entity;

architecture rtl of spi_common is
    signal r_sample_shf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
begin
    o_data_shf <= r_sample_shf;
    o_data <= r_sample_shf when o_sample_done = '1';

    -- Shift data out on `o_out`
    p_shift: process(i_sclk, i_cs_n)
        variable v_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
        variable v_count: integer range 0 to int_max(G_DATA_WIDTH);
    begin
        if i_cs_n /= '0' then
            v_count := 0;
            o_shift_done <= '0';
        elsif rising_edge(i_sclk) then
            o_shift_done <= '0';

            if v_count = 0 then
                v_buf := i_data;
            end if;

            o_out <= v_buf(v_buf'high - v_count);
            v_count := v_count + 1;

            if v_count >= G_DATA_WIDTH then
                v_count := 0;
                o_shift_done <= '1';
            end if;
        end if;
    end process p_shift;

    -- Sample data and place it in the buffer. This notifies in `o_rdy`
    p_sample: process(i_sclk, i_cs_n)
        variable v_count: integer range 0 to int_max(G_DATA_WIDTH);

    begin
        if i_cs_n /= '0' then
            v_count := 0;
            o_sample_done <= '0';
        elsif falling_edge(i_sclk) then
            o_sample_done <= '0';

            r_sample_shf(r_sample_shf'high - v_count) <= i_in;
            v_count := v_count + 1;

            if v_count >= G_DATA_WIDTH then
                v_count := 0;
                o_sample_done <= '1';
            end if;
        end if;
    end process p_sample;

end architecture rtl;
