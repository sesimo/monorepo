
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity edge_detect is
    generic (
        C_FROM: std_logic := '0';
        C_TO: std_logic := '1'
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_sig: in std_logic;
        o_edge: out std_logic
    );
end entity edge_detect;

architecture rtl of edge_detect is
    signal r_last: std_logic;
begin
    o_edge <= '1' when (i_sig = C_TO and r_last = C_FROM) else '0';

    p_last: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_last <= C_TO;
            else
                r_last <= i_sig;
            end if;
        end if;
    end process p_last;
end architecture rtl;
