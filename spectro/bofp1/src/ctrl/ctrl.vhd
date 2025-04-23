
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

        i_fifo_raw_data: in std_logic_vector(15 downto 0);
        i_fifo_pl_data: in std_logic_vector(15 downto 0);
        i_fifo_raw_wmark: in std_logic;
        i_fifo_pl_wmark: in std_logic;
        o_fifo_raw_rd: out std_logic;
        o_fifo_pl_rd: out std_logic;

        o_fifo_wmark: out std_logic;

        i_errors: in t_err_bitmap;
        io_regmap: inout t_regmap
    );
end entity ctrl;

architecture behaviour of ctrl is
    signal r_rst_n_mux: std_logic := '0';
    signal r_spi_active: std_logic;

    signal r_out: std_logic_vector(15 downto 0);
    signal r_out_shf: std_logic_vector(7 downto 0);
    signal r_in_buf: std_logic_vector(7 downto 0);

    -- Streaming from FIFO
    signal r_streaming: boolean;

    type t_stream is (S_RAW, S_PIPELINE);
    signal r_stream_mode: t_stream;

    signal r_shift_done: std_logic;
    signal r_sample_done: std_logic;

    signal r_shift_count: std_logic_vector(1 downto 0);
    signal r_sample_count: std_logic_vector(1 downto 0);

    -- Counter roll-over
    signal r_shift_rolled: std_logic;
    signal r_sample_rolled: std_logic;

    signal r_reg_raw: std_logic_vector(7 downto 0);
    signal r_reg_rdy: std_logic;

    signal r_errors: t_err_bitmap;
    signal r_err_clear: std_logic;

    signal r_fifo_rd: std_logic;

    -- Current range of the SPI output shift register
    function cur_shf_range(data: std_logic_vector; count: unsigned)
    return std_logic_vector is
        variable head: integer;
    begin
        head := data'high - to_integer(count) * 8;

        return data(head downto head - 7);
    end function cur_shf_range;
begin
    r_rst_n_mux <= '0' when (i_rst_n = '0' or r_spi_active = '0') else '1';

    -- Set errors in the regmap.
    u_err: entity work.ctrl_err
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_clear => r_err_clear,
            i_rising => r_errors or i_errors,
            o_persisted => io_regmap(t_reg'pos(REG_STATUS))(c_err_len-1 downto 0)
        );

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
            o_sample_done => r_sample_done,
            o_active => r_spi_active
        );

    u_sample_count: entity work.counter
        generic map(
            G_WIDTH => 2
        )
        port map(
            i_clk => i_clk,
            i_rst_n => r_rst_n_mux,
            i_en => r_sample_done,
            i_max => std_logic_vector(to_unsigned(2, 2)),
            o_cnt => r_sample_count,
            o_roll => r_sample_rolled
        );

    u_shift_count: entity work.counter
        generic map(
            G_WIDTH => 2
        )
        port map(
            i_clk => i_clk,
            i_rst_n => r_rst_n_mux,
            i_en => r_shift_done,
            i_max => std_logic_vector(to_unsigned(2, 2)),
            o_cnt => r_shift_count,
            o_roll => r_shift_rolled
        );

    p_out: process(all)
    begin
        if r_streaming then
            if r_stream_mode = S_RAW then
                r_out <= i_fifo_raw_data;
            else
                r_out <= i_fifo_pl_data;
            end if;
        else
            r_out <= (others => '0');
        end if;
    end process p_out;

    -- Load current part of the data that is to be shifted out
    p_out_shf: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if r_rst_n_mux /= '0' then
                r_out_shf <= cur_shf_range(r_out, unsigned(r_shift_count));
            end if;
        end if;
    end process p_out_shf;

    -- Read from the FIFO whenever the last value has been shifted out in
    -- streaming mode. This depends on first-word write-through support in the
    -- FIFO.
    p_stream_load: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_fifo_rd <= '0';

            if r_streaming and r_shift_rolled = '1' then
                r_fifo_rd <= '1';
            end if;
        end if;
    end process p_stream_load;

    -- Forward read signal to the correct FIFO
    p_rd_mux: process(all)
    begin
        o_fifo_pl_rd <= '0';
        o_fifo_raw_rd <= '0';

        if r_stream_mode = S_RAW then
            o_fifo_raw_rd <= r_fifo_rd;
        else
            o_fifo_pl_rd <= r_fifo_rd;
        end if;
    end process p_rd_mux;

    -- Load the first 8 bits into a register to contain the register address
    -- and write bit.
    p_reg: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_reg_rdy <= '0';

            if r_sample_done = '1' and unsigned(r_sample_count) = 0 then
                r_reg_rdy <= '1';
                r_reg_raw <= r_in_buf;
            end if;
        end if;
    end process p_reg;

    -- Enter streaming mode. This is only done after shifting has completed,
    -- to ensure that we don't read from fifo before the second word. The
    -- first word is the previously read value, or the value from 
    -- first word write through.
    p_stream: process(i_clk)
        variable is_read: boolean;
    begin
        if rising_edge(i_clk) then
            is_read := not is_write(r_reg_raw);

            if r_rst_n_mux = '0' then
                r_streaming <= false;
                r_stream_mode <= S_RAW;
            elsif not r_streaming and r_shift_rolled = '1' and is_read then
                case parse_reg(r_reg_raw) is
                    when REG_STREAM_RAW =>
                        r_streaming <= true;
                        r_stream_mode <= S_RAW;
                    
                    when REG_STREAM_PL =>
                        r_streaming <= true;
                        r_stream_mode <= S_PIPELINE;

                    when others => null;
                end case;
            end if;
        end if;
    end process p_stream;

    p_fifo_wmark: process(all)
    begin
        if get_prc(io_regmap, PRC_WMARK_SRC) = '1' then
            o_fifo_wmark <= i_fifo_pl_wmark;
        else
            o_fifo_wmark <= i_fifo_raw_wmark;
        end if;
    end process p_fifo_wmark;

    -- Read registere value
    p_read: process(i_clk)
        variable is_read: boolean;
    begin
        if rising_edge(i_clk) then
            is_read := not is_write(r_reg_raw);

            if i_rst_n = '0' then
            elsif r_reg_rdy = '1' and is_read then
                -- Dummy
            end if;
        end if;
    end process p_read;

    -- Handling writing operations
    p_write: process(i_clk)
        variable reg: t_reg;
    begin
        if rising_edge(i_clk) then
            o_ccd_sample <= '0';
            o_rst <= '0';
            r_err_clear <= '0';

            if i_rst_n = '0' then
                io_regmap <= c_regmap_default;
            elsif r_sample_rolled = '1' and is_write(r_reg_raw) then
                reg := parse_reg(r_reg_raw);

                case reg is
                    when REG_SAMPLE =>
                        o_ccd_sample <= '1';

                    when REG_RESET =>
                        o_rst <= '1';

                    when REG_STATUS =>
                        r_err_clear <= '1';

                    when REG_SHDIV1 | REG_SHDIV2 | REG_SHDIV3
                         | REG_PRC_CONTROL | REG_TOTAL_AVG_N
                         | REG_MOVING_AVG_N =>
                        set_reg(io_regmap, reg, r_in_buf);

                    when others => null;
                end case;
            end if;
        end if;
    end process p_write;

end architecture behaviour;
