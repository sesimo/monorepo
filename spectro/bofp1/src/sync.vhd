library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- brief Double flip flop for input synchronization
entity dff is 
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
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
            if i_rst_n = '0' then
                o_sig <= 'X';
                r_unsafe <= 'X';
            else
                o_sig <= r_unsafe;
                r_unsafe <= i_sig;
            end if;
        end if;
    end process p_dff;

end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- brief Enable generator
entity enable is
    generic (
        G_CLK_DIV: std_logic_vector := "1"
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        o_enable: out std_logic
    );
end entity enable;

architecture rtl of enable is
    signal r_count: integer;
begin

    -- Generate enable signal
    p_enable: process(i_clk) 
    begin
        if rising_edge(i_clk) then
            o_enable <= '0';
            r_count <= r_count + 1;

            if i_rst_n = '0' then
                r_count <= 0;
            elsif r_count = 0 then
                o_enable <= '1';
            elsif r_count >= unsigned(G_CLK_DIV) - 1 then
                r_count <= 0;
            end if;
        end if;
    end process p_enable;

end architecture rtl;
