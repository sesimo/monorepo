
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ads8329 is
    generic (
        G_RESOLUTION: integer := 16;
        G_CLK_DIV: integer
    );

    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        o_busy: out std_logic;

        i_pin_eoc: in std_logic;
        o_pin_stconv: out std_logic;

        i_spi_rdy: in std_logic;
        o_spi_enable: out std_logic
    );
end entity ads8329;

architecture rtl of ads8329 is
    type t_state is (S_IDLE, S_CONVERTING, S_READ);
    signal r_state: t_state;

    signal r_enable: std_logic;

    signal r_eoc: std_logic;
begin
    -- Double flipflop to synchronize inputs
    u_dff_eoc: entity work.dff(rtl) port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_sig => i_pin_eoc,
        o_sig => r_eoc
    );

    -- Enable generator
    u_enable: entity work.enable(rtl) generic map(
        G_CLK_DIV => std_logic_vector(to_unsigned(G_CLK_DIV, 8))
    ) port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        o_enable => r_enable
    );

    p_conv: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_IDLE;

                o_busy <= '0';
                
                o_pin_stconv <= '0';
                o_spi_enable <= '0';
            elsif r_enable = '1' then
                o_pin_stconv <= '0';

                case r_state is
                    when S_IDLE =>
                        -- Wait for start signal
                        if i_start = '1' then
                            o_pin_stconv <= '1';
                            o_busy <= '1';

                            r_state <= S_CONVERTING;
                        end if;
                    when S_CONVERTING =>
                        -- Started, wait for conversion to complete
                        if r_eoc = '1' then
                            o_spi_enable <= '1';

                            r_state <= S_READ;
                        end if;
                    when S_READ =>
                        -- Conversion done, read out
                        if i_spi_rdy = '1' then
                            o_busy <= '0';
                            o_spi_enable <= '0';

                            r_state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process p_conv;

end architecture rtl;
