
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

entity pwm is
    generic (
        G_WIDTH: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_period: in std_logic_vector(G_WIDTH-1 downto 0);
        i_pulse: in std_logic_vector(G_WIDTH-1 downto 0);
        
        o_clk: out std_logic
    );
end entity pwm;

architecture rtl of pwm is
    type t_state is (S_HIGH_CYC, S_LOW_CYC);
    signal r_state: t_state;
begin

    p_pwm: process(i_clk)
        variable v_count_per: integer range 0 to int_max(G_WIDTH) := 0;
        variable v_count_dc: integer range 0 to int_max(G_WIDTH) := 0;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                o_clk <= '0';
                v_count_per := 0;
                v_count_dc := 0;
                r_state <= S_HIGH_CYC;
            else
                o_clk <= '1';
                v_count_per := v_count_per + 1;

                case r_state is
                    -- Keep high for the duration of the pulse
                    when S_HIGH_CYC =>
                        v_count_dc := v_count_dc + 1;

                        if v_count_dc >= unsigned(i_pulse) then
                            r_state <= S_LOW_CYC;
                            v_count_dc := 0;
                        end if;
                    -- Once the pulse has ended, keep low for remainder of
                    -- period
                    when S_LOW_CYC =>
                        o_clk <= '0';

                        if v_count_per >= unsigned(i_period) then
                            r_state <= S_HIGH_CYC;
                            v_count_per := 0;
                        end if;
                end case;
            end if;
        end if;
    end process p_pwm;

end architecture rtl;
