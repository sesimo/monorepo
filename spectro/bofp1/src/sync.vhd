library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Flip flop
entity ff is 
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_sig: in std_logic;

        o_sig: out std_logic
    );
end entity ff;

architecture rtl of ff is
    signal r_unsafe: std_logic;
begin

    p_ff: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                o_sig <= 'X';
                r_unsafe <= 'X';
            else
                o_sig <= r_unsafe;
                r_unsafe <= i_sig;
            end if;
        end if;
    end process p_ff;

end architecture rtl;
