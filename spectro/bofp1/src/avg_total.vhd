
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

entity avg_total is
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_en: in std_logic;
        i_rdy: in std_logic;
        i_data: in std_logic_vector(15 downto 0);
        i_n: in std_logic_vector(4 downto 0);
        o_busy: out std_logic;
        o_rdy: out std_logic;
        o_data: out std_logic_vector(15 downto 0)
    );
end entity avg_total;

architecture behaviour of avg_total is
    type t_state is (S_FIRST, S_NORMAL, S_LAST);
    signal r_state: t_state;

    signal r_en_fall: std_logic;
    signal r_cnt_rst_n: std_logic;
    signal r_cnt_fall_roll: std_logic;

    signal r_rd_en: std_logic;
    signal r_wr_en: std_logic;

    signal r_rdy1: std_logic;
    signal r_rdy2: std_logic;

    signal r_val: unsigned(20 downto 0);
    signal r_memval: std_logic_vector(20 downto 0);
    signal r_addr: unsigned(11 downto 0);

    signal r_loaded: boolean;
begin
    -- Keep temporary values in memory
    u_ram: entity work.frame_ram
        generic map(
            C_WIDTH => 21
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_addr => std_logic_vector(r_addr),
            i_wr_en => r_wr_en,
            i_rd_en => r_rd_en,
            i_wr_data => std_logic_vector(r_val),
            o_rd_data => r_memval
        );

    -- Don't count when not in normal mode
    r_cnt_rst_n <= '0' when (i_rst_n = '0' or r_state /= S_NORMAL) else '1';

    u_cnt_fall: entity work.counter
        generic map(
            G_WIDTH => i_n'length
        )
        port map(
            i_clk => i_clk,
            i_rst_n => r_cnt_rst_n,
            i_en => r_en_fall,
            i_max => std_logic_vector(unsigned(i_n) - 2),
            o_roll => r_cnt_fall_roll
        );

    -- Detect falling edge of enable signal. This is used to detect the end
    -- of a frame.
    u_fall: entity work.edge_detect
        generic map(
            C_TO => '0',
            C_FROM => '1'
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_sig => i_en,
            o_edge => r_en_fall
        );

    -- Load from memory whenever going into a non S_FIRST state (for the
    -- first element) or when i_rdy=1 (for all other elements). This causes
    -- r_memval to be updated the cycle after the computation has completed,
    -- so that it is ready for when the next computation is to be done.
    p_load: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_loaded <= true;
            r_rd_en <= '0';

            if r_state = S_FIRST then
                r_loaded <= false;
            elsif not r_loaded or r_rdy2 = '1' then
                r_rd_en <= '1';
            end if;
        end if;
    end process p_load;

    p_store: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_wr_en <= '0';

            if r_rdy1 = '1' and r_state /= S_LAST then
                r_wr_en <= '1';
            end if;
        end if;
    end process p_store;

    -- Update read/write address after writing to RAM
    -- This does not handle overflow checking but resets to 0 when the pipeline
    -- stage is not active.
    p_addr: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_en = '0' then
                r_addr <= (others => '0');
            elsif r_rdy2 = '1' then
                r_addr <= r_addr + 1;
            end if;
        end if;
    end process p_addr;

    p_calc: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rdy = '1' then
                case r_state is
                    when S_FIRST =>
                        r_val <= resize(unsigned(i_data), r_val'length);

                    when S_NORMAL =>
                        r_val <= resize(unsigned(r_memval) + unsigned(i_data),
                                 r_val'length);

                    when S_LAST =>
                        r_val <= resize(
                                 (unsigned(r_memval) + unsigned(i_data))
                                 / unsigned(i_n),
                                 r_val'length);
                end case;
            end if;
        end if;
    end process p_calc;

    p_rdy: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_rdy <= '0';
            r_rdy1 <= i_rdy;
            r_rdy2 <= r_rdy1;

            if r_state = S_LAST then
                o_rdy <= i_rdy;
            end if;
        end if;
    end process p_rdy;

    -- Busy when enable=1, or in the cycle enable is falling, or when in
    -- any state but the first.
    p_busy: process(i_clk)
        variable busy: boolean;
    begin
        if rising_edge(i_clk) then
            busy := i_en = '1' or r_en_fall = '1' or r_state /= S_FIRST;
            o_busy <= '1' when busy else '0';
        end if;
    end process p_busy;

    -- Handle state changes in between frames
    p_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_FIRST;
            else
                case r_state is
                    when S_FIRST =>
                        if r_en_fall = '1' then
                            r_state <= S_NORMAL;
                        end if;

                    when S_NORMAL =>
                        if r_cnt_fall_roll = '1' then
                            r_state <= S_LAST;
                        end if;

                    when S_LAST =>
                        if r_en_fall = '1' then
                            r_state <= S_FIRST;
                        end if;

                end case;
            end if;
        end if;
    end process p_state;

    o_data <= std_logic_vector(r_val(o_data'range));

end architecture behaviour;
