
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
    signal r_last_tmp: std_logic;
    signal r_edge_buf: std_logic;

    signal r_edge_fall: boolean;
begin
    o_edge <= r_edge_buf;
    r_edge_buf <= '1' when (i_sig = C_TO and r_last = C_FROM and not r_edge_fall) else '0';

    p_fall: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if r_edge_buf = '1' then
                r_edge_fall <= true;
            else
                r_edge_fall <= false;
            end if;
        end if;
    end process p_fall;

    p_last: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_last <= C_TO;
                r_last_tmp <= C_TO;
            else
                r_last <= r_last_tmp;
                r_last_tmp <= i_sig;
            end if;
        end if;
    end process p_last;
end architecture rtl;
