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
        G_CLK_DIV: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        o_enable: out std_logic
    );
end entity enable;

architecture rtl of enable is
begin

    -- Generate enable signal
    p_enable: process(i_clk) 
        variable v_count: integer := 0;
    begin
        if rising_edge(i_clk) then
            o_enable <= '0';

            if i_rst_n = '0' then
                v_count := 0;
            elsif v_count = G_CLK_DIV then
                v_count := 0;
                o_enable <= '1';
            else
                v_count := v_count + 1;
            end if;
        end if;
    end process p_enable;

end architecture rtl;
