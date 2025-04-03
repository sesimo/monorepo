
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
        i_clk: in std_logic;
        i_rst_n: in std_logic;

        i_shift_en: in std_logic;
        i_sample_en: in std_logic;

        i_in: in std_logic;
        i_cs_n: in std_logic;
        o_out: out std_logic;

        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);

        o_sample_done: inout std_logic;
        o_shift_done: inout std_logic
    );
end entity;

architecture rtl of spi_common is
    signal r_rst_n_mux: std_logic;

    -- TODO:
    constant c_cnt_bits: natural := 5; --bits_needed(G_DATA_WIDTH);
begin
    r_rst_n_mux <= '0' when (i_cs_n /= '0' or i_rst_n = '0') else '1';

    b_shf: block
        signal r_shf_cnt: std_logic_vector(c_cnt_bits-1 downto 0);
        signal r_next: std_logic;
    begin

        -- Count the number of shifts done, rolling over to zero when reaching
        -- G_DATA_WIDTH
        u_shf_cnt: entity work.counter
            generic map(
                G_WIDTH => c_cnt_bits
            )
            port map(
                i_clk => i_clk,
                i_rst_n => r_rst_n_mux,
                i_en => i_shift_en,
                i_max => std_logic_vector(
                    to_unsigned(G_DATA_WIDTH, c_cnt_bits)),
                o_roll => o_shift_done,
                o_cnt => r_shf_cnt
            );

        -- Load next bit into the register to ensure that it is ready when
        -- i_shift_en goes high
        p_shf_load: process(i_clk)
        begin
            if rising_edge(i_clk) then
                if r_rst_n_mux /= '0' then
                    r_next <= i_data(i_data'high - to_integer(unsigned(r_shf_cnt)));
                end if;
            end if;
        end process p_shf_load;

        -- Shift data out on data line
        p_shf_do: process(i_clk)
        begin
            if rising_edge(i_clk) then
                if i_shift_en = '1' then
                    o_out <= r_next;
                end if;
            end if;
        end process p_shf_do;

    end block b_shf;

    b_smpl: block
        signal r_smpl_cnt: std_logic_vector(c_cnt_bits-1 downto 0);
        signal r_smpl_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    begin

        -- Count the number of shifts done, rolling over to zero when reaching
        -- G_DATA_WIDTH
        u_smpl_cnt: entity work.counter
            generic map(
                G_WIDTH => c_cnt_bits
            )
            port map(
                i_clk => i_clk,
                i_rst_n => r_rst_n_mux,
                i_en => i_sample_en,
                i_max => std_logic_vector(
                    to_unsigned(G_DATA_WIDTH, c_cnt_bits)),
                o_roll => o_sample_done,
                o_cnt => r_smpl_cnt
            );

        -- Load i_in into the buffer
        p_smpl_do: process(i_clk)
            variable v_index: integer;
        begin
            if rising_edge(i_clk) then
                if i_sample_en = '1' then
                    v_index := r_smpl_buf'high - to_integer(unsigned(r_smpl_cnt));
                    r_smpl_buf(v_index) <= i_in;
                end if;
            end if;
        end process p_smpl_do;

        o_data <= r_smpl_buf;

    end block b_smpl;

end architecture rtl;
