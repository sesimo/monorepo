
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

-- brief Enable generator
entity enable is
    generic (
        G_WIDTH: integer
    );
    port (
        i_clk: in std_logic;
        i_clk_div: in std_logic_vector(G_WIDTH-1 downto 0);
        i_rst_n: in std_logic;
        o_enable: out std_logic
    );
end entity enable;

architecture rtl of enable is
    signal r_count: integer range 0 to int_max(G_WIDTH);
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
            elsif r_count >= unsigned(i_clk_div) - 1 then
                r_count <= 0;
            end if;
        end if;
    end process p_enable;

end architecture rtl;
