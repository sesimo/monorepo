
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
        i_n: in std_logic_vector(3 downto 0);
        o_busy: out std_logic;
        o_rdy: out std_logic;
        o_data: out std_logic_vector(15 downto 0)
    );
end entity avg_total;

architecture behaviour of avg_total is
    type t_frame_state is (S_FRAME_IDLE, S_FIRST, S_NORMAL, S_LAST);
    signal r_frame_state: t_frame_state;

    type t_pix_state is (S_PIX_IDLE, S_CALC_ADD, S_CALC_DIV, S_STORE, S_LOAD, S_READY);
    signal r_pix_state: t_pix_state;

    signal r_en_fall: std_logic;
    signal r_en_fall_sync: std_logic;
    signal r_cnt_rst_n: std_logic;
    signal r_cnt_roll: std_logic;
    signal r_cnt_roll_sync: std_logic;

    signal r_rd_en: std_logic;
    signal r_wr_en: std_logic;

    signal r_val_add: unsigned(20 downto 0);
    signal r_val: unsigned(20 downto 0);
    signal r_memval: std_logic_vector(20 downto 0);
    signal r_addr: unsigned(11 downto 0);
    signal r_single: boolean;
    signal r_double: boolean;

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

    -- Don't count when in idle
    r_cnt_rst_n <= '0' when (i_rst_n = '0' or r_frame_state = S_FRAME_IDLE) else '1';

    p_n_cases: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_single <= false;
            r_double <= false;

            if i_n /= (i_n'range => 'U') then
                if unsigned(i_n) = 1 then
                    r_single <= true;
                elsif unsigned(i_n) = 2 then
                    r_double <= true;
                end if;
            else
                r_single <= true;
            end if;
        end if;
    end process p_n_cases;

    u_cnt_fall: entity work.counter
        generic map(
            G_WIDTH => i_n'length
        )
        port map(
            i_clk => i_clk,
            i_rst_n => r_cnt_rst_n,
            i_en => r_en_fall,
            i_max => std_logic_vector(unsigned(i_n) - 1),
            o_roll => r_cnt_roll
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

            if r_frame_state = S_FRAME_IDLE then
                r_loaded <= false;
            elsif not r_loaded or r_pix_state = S_LOAD then
                r_rd_en <= '1';
            end if;
        end if;
    end process p_load;

    -- Write to memory, unless in the last state
    p_store: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_wr_en <= '0';

            if r_pix_state = S_STORE and r_frame_state /= S_LAST and not r_single then
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
            if i_rst_n = '0' then
                r_addr <= (others => '0');
            elsif r_pix_state = S_LOAD then
                if i_en = '0' then
                    r_addr <= (others => '0');
                else
                    r_addr <= r_addr + 1;
                end if;
            end if;
        end if;
    end process p_addr;

    -- Add to the sum
    p_calc_add: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if r_pix_state = S_CALC_ADD and i_rdy = '1' then
                case r_frame_state is
                    when S_FIRST =>
                        r_val_add <= resize(unsigned(i_data), r_val_add'length);

                    when S_NORMAL | S_LAST =>
                        r_val_add <= resize(
                                     unsigned(r_memval) + unsigned(i_data),
                                     r_val_add'length);

                    when others => null;
                end case;
            end if;
        end if;
    end process p_calc_add;

    -- Divide the sum by N, if in the last state
    p_calc_div: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if r_pix_state = S_CALC_DIV then
                case r_frame_state is
                    when S_FIRST | S_NORMAL =>
                        r_val <= r_val_add;

                    when S_LAST =>
                        r_val <= const_div(r_val_add, unsigned(i_n), 61);

                    when others => null;
                end case;
            end if;
        end if;
    end process p_calc_div;

    p_pix_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_pix_state <= S_CALC_ADD;
            else
                case r_pix_state is
                    when S_PIX_IDLE =>
                        if i_en = '1' then
                            r_pix_state <= S_CALC_ADD;
                        end if;
                    when S_CALC_ADD =>
                        if i_rdy = '1' then
                            r_pix_state <= S_CALC_DIV;
                        end if;

                    when S_CALC_DIV =>
                        r_pix_state <= S_STORE;

                    when S_STORE =>
                        r_pix_state <= S_LOAD;

                    when S_LOAD =>
                        r_pix_state <= S_READY;

                    when S_READY =>
                        r_pix_state <= S_PIX_IDLE;

                end case;
            end if;
        end if;
    end process p_pix_state;

    -- Synchronise the enable signals needed to transition between frame
    -- states. This is done because we only want to transition when the
    -- pixel is in the ready state.
    p_ready_sync: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_en_fall_sync <= '0';
                r_cnt_roll_sync <= '0';
            else
                if r_pix_state = S_READY then
                    r_en_fall_sync <= '0';
                    r_cnt_roll_sync <= '0';
                end if;

                if r_en_fall = '1' then
                    r_en_fall_sync <= '1';
                end if;

                if r_cnt_roll = '1' then
                    r_cnt_roll_sync <= '1';
                end if;
            end if;
        end if;
    end process p_ready_sync;

    -- Handle state changes in between frames
    p_frame_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_frame_state <= S_FRAME_IDLE;
            else
                case r_frame_state is
                    when S_FRAME_IDLE =>
                        if i_en = '1' then
                            r_frame_state <= S_FIRST;
                        end if;

                    when S_FIRST =>
                        if r_pix_state = S_READY and r_en_fall_sync = '1' then
                            if r_single then
                                r_frame_state <= S_FRAME_IDLE;
                            elsif r_double then
                                r_frame_state <= S_LAST;
                            else
                                r_frame_state <= S_NORMAL;
                            end if;
                        end if;

                    when S_NORMAL =>
                        if r_pix_state = S_READY and r_cnt_roll_sync = '1' then
                            r_frame_state <= S_LAST;
                        end if;

                    when S_LAST =>
                        if r_pix_state = S_READY and r_en_fall_sync = '1' then
                            r_frame_state <= S_FRAME_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process p_frame_state;

    p_rdy: process(all)
    begin
        if r_pix_state = S_READY then
            if r_frame_state = S_LAST then
                o_rdy <= '1';
            elsif r_frame_state = S_FIRST and r_single then
                o_rdy <= '1';
            else
                o_rdy <= '0';
            end if;
        else
            o_rdy <= '0';
        end if;
    end process p_rdy;

    o_data <= std_logic_vector(r_val(o_data'range));
    o_busy <= '1' when r_frame_state /= S_FRAME_IDLE else '0';

end architecture behaviour;
