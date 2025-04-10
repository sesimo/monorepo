
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

entity avg_moving is
    generic (
        C_NUM_ELEMENTS: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_rdy: in std_logic;
        i_n: in std_logic_vector(7 downto 0);
        i_data: in std_logic_vector(15 downto 0);
        o_rdy: out std_logic;
        o_data: out std_logic_vector(15 downto 0)
    );
end entity avg_moving;

architecture behaviour of avg_moving is
    signal r_cnt: std_logic_vector(bits_needed(C_NUM_ELEMENTS)-1 downto 0);
    signal r_cnt_rolled: std_logic;

    type t_state is (S_START, S_NORMAL);
    signal r_state: t_state;

    constant c_sum_max: integer := (2**16-1) * ((2**i_n'length-1) * 2 + 1);
    constant c_sum_bits: integer := bits_needed(c_sum_max);
    signal r_sum: unsigned(c_sum_bits-1 downto 0);

    signal r_last: std_logic_vector(15 downto 0);
    signal r_fifo_rd: std_logic;
    signal r_fifo_wr: std_logic;

    signal r_fifo_pop: std_logic;

    signal r_n_total: unsigned(9 downto 0);
begin

    u_fifo: entity work.window_fifo
        generic map(
            C_SIZE => 64
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_rd => r_fifo_rd,
            i_wr => r_fifo_wr,
            i_data => i_data,
            o_data => r_last
        );

    u_cnt: entity work.counter
        generic map (
            G_WIDTH => bits_needed(C_NUM_ELEMENTS)
        )
        port map (
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => i_rdy,
            i_max => std_logic_vector(to_unsigned(C_NUM_ELEMENTS, r_cnt'length)),
            o_cnt => r_cnt,
            o_roll => r_cnt_rolled
        );

    p_n_total: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n /= '0' then
                -- Left, right and center
                r_n_total <= resize(unsigned(i_n) * 2 + 1, r_n_total'length);
            end if;
        end if;
    end process p_n_total;

    -- Delay popping until one cycle after putting into the FIFO
    p_fifo_pop_delay: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_fifo_pop <= i_rdy;
        end if;
    end process p_fifo_pop_delay;

    p_fifo_pop: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_fifo_rd <= '0';

            if r_state = S_NORMAL and r_fifo_pop = '1' then
                r_fifo_rd <= '1';
            end if;
        end if;
    end process p_fifo_pop;

    p_fifo_put: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_fifo_wr <= '0';

            if i_rdy = '1' then
                r_fifo_wr <= '1';
            end if;
        end if;
    end process p_fifo_put;

    -- Adjust current sum by subtracting the leftmost value of the window
    -- and adding the rightmost value.
    p_shift: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_sum <= (others => '0');
            elsif i_rdy = '1' then
                if r_state = S_START then
                    r_sum <= r_sum + unsigned(i_data);
                elsif r_state = S_NORMAL then
                    r_sum <= r_sum - unsigned(r_last) + unsigned(i_data);
                end if;
            end if;
        end if;
    end process p_shift;

    -- Calculate next value
    p_calc: process(i_clk)
        variable val: unsigned(r_sum'range);
    begin
        if rising_edge(i_clk) then
            if i_rdy = '1' then
                val := r_sum / unsigned(r_n_total);
                o_data <= std_logic_vector(resize(val, o_data'length));
            end if;
        end if;
    end process p_calc;

    -- Signal ready when not at the edges of the frame. In this case,
    -- o_rdy becomes the value of i_rdy delayed by one cycle.
    p_rdy: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_rdy <= '0';

            if r_state = S_NORMAL then
                o_rdy <= i_rdy;
            end if;
        end if;
    end process p_rdy;

    p_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_START;
            elsif i_rdy = '1' then
                case r_state is
                    when S_START =>
                        if unsigned(r_cnt) >= r_n_total-1 then
                            r_state <= S_NORMAL;
                        end if;

                    when S_NORMAL =>
                        if r_cnt_rolled = '1' then
                            r_state <= S_START;
                        end if;

                end case;
            end if;
        end if;
    end process p_state;

end architecture behaviour;
