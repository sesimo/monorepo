
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- brief Double flip flop for input synchronization
-- This does the same as the single-bit one, but due to poor support for
-- generic types in various tools it is not worth the hassle to get the
-- two in the same entity.
entity cdc_vector is 
    generic (
        G_WIDTH: integer
    );
    port (
        i_clk: in std_logic;
        i_sig: in std_logic_vector(G_WIDTH-1 downto 0);

        o_sig: out std_logic_vector(G_WIDTH-1 downto 0)
    );
end entity cdc_vector;

architecture rtl of cdc_vector is
    signal r_unsafe: std_logic_vector(G_WIDTH-1 downto 0);
begin

    p_dff: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_sig <= r_unsafe;
            r_unsafe <= i_sig;
        end if;
    end process p_dff;

end architecture rtl;
