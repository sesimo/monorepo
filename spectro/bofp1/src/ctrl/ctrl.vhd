
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity ctrl is
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        o_ccd_sample: out std_logic;
        o_rst: out std_logic;

        i_sclk: in std_logic;
        i_cs_n: in std_logic;

        i_mosi: in std_logic;
        o_miso: out std_logic;

        i_fifo_empty: in std_logic;
        i_fifo_data: in std_logic_vector(15 downto 0);
        o_fifo_rd: out std_logic;
        o_regmap: out t_regmap
    );
end entity ctrl;

architecture behaviour of ctrl is
    signal r_out: std_logic_vector(15 downto 0);
    signal r_out_shf: std_logic_vector(7 downto 0);
    signal r_in_buf: std_logic_vector(7 downto 0);

    -- Streaming from FIFO
    signal r_streaming: boolean;

    signal r_shift_done: std_logic;
    signal r_sample_done: std_logic;

    signal r_shift_count: integer := 0;

    -- Current range of the SPI output shift register
    function cur_shf_range(data: std_logic_vector; count: integer)
    return std_logic_vector is
        variable v_head: integer;
    begin
        v_head := data'high - count * 8;

        return data(v_head downto v_head - 7);
    end function cur_shf_range;

    function count_inc(cur: integer) return integer is
    begin
        return (cur + 1) mod 2;
    end function count_inc;
begin

    -- TODO: ctrl data
    r_out <= i_fifo_data;

    -- Current part of the data that is to be shifted out
    r_out_shf <= cur_shf_range(r_out, r_shift_count);

    u_spi: entity work.spi_sub(rtl)
        generic map(
            G_DATA_WIDTH => 8
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_sclk => i_sclk,
            i_cs_n => i_cs_n,
            i_mosi => i_mosi,
            i_data => r_out_shf,
            o_miso => o_miso,
            o_data_shf => r_in_buf,
            o_shift_done => r_shift_done,
            o_sample_done => r_sample_done
        );

    p_count: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' or i_cs_n /= '0' then
                r_shift_count <= 0;
            elsif r_shift_done = '1' then
                r_shift_count <= count_inc(r_shift_count);
            end if;
        end if;
    end process p_count;

    -- Read from the FIFO whenever the last value has been shifted out in
    -- streaming mode. This depends on first-word write-through support in the
    -- FIFO.
    p_stream: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_fifo_rd <= '0';

            if r_streaming and r_shift_done = '1' and r_shift_count = 1 then
                if i_fifo_empty /= '1' then
                    o_fifo_rd <= '1';
                end if;
            end if;
        end if;
    end process p_stream;

    p_handle_in: process(i_clk)
        variable v_count: integer range 0 to 1;
        variable v_reg_raw: std_logic_vector(3 downto 0);
    begin
        if rising_edge(i_clk) then
            o_rst <= '0';
            o_ccd_sample <= '0';

            if i_rst_n = '0' or i_cs_n /= '0' then
                v_count := 0;
                r_streaming <= false;

                -- Only reload defaults on reset
                if i_rst_n = '0' then
                    o_regmap <= c_regmap_default;
                end if;
            elsif r_sample_done = '1' then
                -- After receiving the first 8 bits. If this is a read
                -- operation, prepare data to be shifted out. If this is
                -- a write operation, wait until after the next 8 bits have
                -- been received.
                if v_count = 0 then
                    -- Perform reading operation
                    -- TODO: Save whole buffer
                    v_reg_raw := r_in_buf(7 downto 4);
                else
                    case parse_reg(v_reg_raw) is
                        when REG_STREAM =>
                            r_streaming <= true;

                        when REG_SAMPLE =>
                            o_ccd_sample <= '1';

                        when REG_RESET =>
                            o_rst <= '1';

                        when REG_CLKDIV =>
                            o_regmap.clkdiv <= r_in_buf;

                        when REG_SHDIV =>
                            o_regmap.shdiv <= r_in_buf;

                        when others => null;
                    end case;
                end if;

                v_count := count_inc(v_count);
            end if;
        end if;
    end process p_handle_in;

end architecture behaviour;
