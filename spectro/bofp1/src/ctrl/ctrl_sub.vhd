
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity ctrl_sub is
    generic (
        G_DATA_WIDTH: integer
    );
    port (
        i_sclk: in std_logic;
        i_cs_n: in std_logic;

        i_mosi: in std_logic;
        o_miso: out std_logic;

        o_rdy: out std_logic;
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);

        i_fifo_empty: in std_logic;
        i_fifo_data: in std_logic_vector(15 downto 0);
        o_fifo_rd: out std_logic
    );
end entity ctrl_sub;

architecture behaviour of ctrl_sub is
    signal r_sample_done: std_logic;
    signal r_shift_done: std_logic;

    signal r_in_buf: std_logic_vector(G_DATA_WIDTH-1 downto 0);

    signal r_out: std_logic_vector(15 downto 0);
    signal r_out_shf: std_logic_vector(3 downto 0);

    -- When entering streaming mode, it will be kept in that state until CS
    -- is released. This means that the user can only stream data while
    -- continuing to hold CS after reading from REG_STREAM
    signal r_streaming: boolean;

    signal r_shf_count: integer;

    -- Current range of the SPI output shift register
    function cur_shf_range(
        data: std_logic_vector;
        count: integer
    ) return std_logic_vector is
        variable v_head: integer;
    begin
        v_head := data'high - count * 4;

        return data(v_head downto v_head - 3);
    end function cur_shf_range;
begin
    o_data <= r_in_buf;

    -- TODO: ctrl data
    r_out <= i_fifo_data when r_streaming else (others => '0');

    -- Count the number of shifts done
    --r_shf_count <= ((r_shf_count + 1) mod 4) when r_shift_done = '1';
    r_out_shf <= cur_shf_range(r_out, r_shf_count) when i_cs_n = '0';

    u_spi: entity work.spi_sub(rtl)
        generic map(
            G_MODE => 1,
            G_DATA_WIDTH => G_DATA_WIDTH
        )
        port map(
            i_sclk => i_sclk,
            i_cs_n => i_cs_n,
            i_mosi => i_mosi,
            i_data => r_out_shf,
            o_miso => o_miso,
            o_data_shf => r_in_buf,
            o_shift_done => r_shift_done,
            o_sample_done => r_sample_done
        );

    p_count: process(i_sclk, i_cs_n)
    begin
        if i_cs_n /= '0' then
            r_shf_count <= 0;
        elsif falling_edge(i_sclk) and r_shift_done = '1' then
            r_shf_count <= (r_shf_count + 1) mod 4;
        end if;
    end process p_count;

    p_handle: process(i_sclk, i_cs_n)
    begin
        if i_cs_n /= '0' then
            o_rdy <= '0';
            r_streaming <= false;
        elsif rising_edge(i_sclk) then
            o_rdy <= '0';

            -- When r_sample_one=1, 4 bits have been received from the SPI
            -- main. This process should determine whether or not to
            -- forward the data to the main clock domain. If streaming mode
            -- has already been entered, the received register/command
            -- is to be discarded.
            if r_sample_done = '1' and not r_streaming then
                -- Whenever not in streaming mode, and 4 bits are received,
                -- they should by default be forwarded to the main clock
                -- domain. Exceptions to this case will clear o_rdy later
                -- in this process.
                o_rdy <= '1';

                -- Sample_done=1 and shift count=1, means that the first 4
                -- bits have been received
                if r_shf_count = 1 then
                    case parse_reg(r_in_buf) is
                        -- Enter streaming mode, and explicitly
                        -- clear o_rdy. This prevents
                        -- forwarding to the main clock domain
                        when REG_STREAM =>
                            r_streaming <= true;
                            o_rdy <= '0';

                        -- Everything else is forwarded
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process p_handle;

    p_stream: process(i_sclk, i_cs_n)
        variable v_outdated: boolean := true;
        variable v_dropped: boolean;
    begin
        if i_cs_n /= '0' then
            v_dropped := true;
            o_fifo_rd <= '0';
        elsif rising_edge(i_sclk) and r_streaming and r_sample_done = '1' then
            o_fifo_rd <= '0';

            -- When starting the last 4 bits, pop from fifo
            if r_shf_count = 3 then
                -- If the CS line has been dropped and picked up again,
                -- and the last stream popped data from FIFO into the register
                -- then the previously popped data can be re-used. This will
                -- not have been previously shifted out onto the SPI bus
                -- since the CS line was dropped.
                if not (v_dropped and not v_outdated) then
                    if i_fifo_empty = '1' then
                        v_outdated := true;
                    else
                        o_fifo_rd <= '0';
                    end if;
                end if;
            end if;

            v_dropped := false;
            v_outdated := false;
        end if;
    end process p_stream;

end architecture behaviour;
