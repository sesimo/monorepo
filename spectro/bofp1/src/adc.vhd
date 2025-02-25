
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ads8329 is
    generic (
        G_STCONV_HOLD_CYC: integer := 10
    );

    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;

        i_pin_eoc: in std_logic;
        o_pin_stconv: inout std_logic;

        o_rd_en: out std_logic
    );
end entity ads8329;

architecture rtl of ads8329 is
    type t_state is (S_IDLE, S_START, S_CONVERTING);
    signal r_state: t_state;

    signal r_stconv: std_logic;
    signal r_stconv_fall: std_logic;

    signal r_eoc: std_logic;
    signal r_cdc_eoc: std_logic;
begin
    u_counter: entity work.counter(rtl)
        generic map(
            G_WIDTH => 8
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_cyc_cnt => std_logic_vector(to_unsigned(G_STCONV_HOLD_CYC, 8)),
            i_start => r_stconv,
            o_int => r_stconv_fall
        );

    p_eoc: process(i_clk)
        variable v_last: std_logic;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_eoc <= '0';
                r_cdc_eoc <= '0';
                v_last := '0';
            else
                if r_eoc = '0' and v_last = '0' then
                    r_eoc <= r_cdc_eoc;
                else
                    r_eoc <= '0';
                end if;

                v_last := r_cdc_eoc;
                r_cdc_eoc <= i_pin_eoc;
            end if;
        end if;
    end process p_eoc;

    p_stconv: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                o_pin_stconv <= '0';
            else
                if r_stconv = '1' then
                    o_pin_stconv <= '1';
                elsif r_stconv_fall = '1' then
                    o_pin_stconv <= '0';
                end if;
            end if;
        end if;
    end process p_stconv;

    p_conv: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_IDLE;
                
                r_stconv <= '0';
                o_rd_en <= '0';
            else 
                o_rd_en <= '0';
                r_stconv <= '0';

                case r_state is
                    when S_IDLE =>
                        -- Wait for start signal
                        if i_start = '1' then
                            r_stconv <= '1';

                            r_state <= S_START;
                        end if;
                    when S_START =>
                        -- Wait for EOC to go low, which indicates the ADC
                        -- is converting.
                        if r_eoc = '0' then
                            r_state <= S_CONVERTING;
                        end if;

                    when S_CONVERTING =>
                        -- Started, wait for conversion to complete
                        if r_eoc = '1' then
                            o_rd_en <= '1';

                            r_state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process p_conv;

end architecture rtl;
