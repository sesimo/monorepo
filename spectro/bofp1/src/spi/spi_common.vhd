
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_common is
    generic (
        G_MODE: integer range 0 to 3;
        G_DATA_WIDTH: integer
    );
    port (
        i_sclk: in std_logic;
        i_cs_n: in std_logic;
        i_in: in std_logic;
        o_out: out std_logic;

        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);

        o_rdy: out std_logic
    );
end entity;

architecture rtl of spi_common is
    constant c_sample_rising: boolean := G_MODE = 0 or G_MODE = 3;
begin

    -- Shift data out on `o_out`
    p_shift: process(i_sclk, i_cs_n)
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
        variable v_count: integer;

        impure function should_shift(signal clk: std_logic) return boolean is
        begin
            if c_sample_rising then
                return falling_edge(clk);
            else
                return rising_edge(clk);
            end if;
        end function;
    begin
        if i_cs_n /= '0' then
            v_count := 0;
            o_out <= 'Z';
        elsif should_shift(i_sclk) then
            if v_count = 0 then
                v_shf_buf := i_data;
            end if;

            v_count := v_count + 1;

            o_out <= v_shf_buf(v_shf_buf'high);
            v_shf_buf := v_shf_buf(v_shf_buf'high-1 downto 0) & "Z";

            if v_count >= G_DATA_WIDTH then
                v_count := 0;
            end if;
        end if;
    end process p_shift;

    -- Sample data and place it in the buffer. This notifies in `o_rdy`
    p_sample: process(i_sclk, i_cs_n)
        variable v_shf_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
        variable v_count: integer;

        impure function should_sample(signal clk: std_logic) return boolean is
        begin
            if c_sample_rising then
                return rising_edge(clk);
            else
                return falling_edge(clk);
            end if;
        end function;
    begin
        if i_cs_n /= '0' then
            v_count := 0;
            o_rdy <= '0';
        elsif should_sample(i_sclk) then
            o_rdy <= '0';

            v_count := v_count + 1;
            v_shf_buf := v_shf_buf(v_shf_buf'high-1 downto 0) & i_in;

            if v_count >= G_DATA_WIDTH then
                v_count := 0;
                o_data <= v_shf_buf;
                o_rdy <= '1';
            end if;
        end if;
    end process p_sample;

end architecture rtl;
