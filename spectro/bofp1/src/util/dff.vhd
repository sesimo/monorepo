library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- brief Double flip flop for input synchronization
entity dff is 
    port (
        i_clk: in std_logic;
        i_sig: in std_logic;

        o_sig: out std_logic
    );
end entity dff;

architecture rtl of dff is
    signal r_unsafe: std_logic;
begin

    p_dff: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_sig <= r_unsafe;
            r_unsafe <= i_sig;
        end if;
    end process p_dff;

end architecture rtl;
