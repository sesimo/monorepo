
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

entity counter is
    generic (
        G_WIDTH: integer
    );

    port (
        i_clk: in std_logic;
        i_en: in std_logic;
        i_max: in std_logic_vector(G_WIDTH-1 downto 0);
        i_rst_n: in std_logic;
        o_cnt: out std_logic_vector(G_WIDTH-1 downto 0);
        o_roll: out std_logic
    );
end entity counter;

architecture rtl of counter is
    signal r_cnt: unsigned(G_WIDTH-1 downto 0);
begin

    p_count: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_roll <= '0';

            if i_rst_n = '0' then
                r_cnt <= (others => '0');
            elsif i_en = '1' then
                r_cnt <= r_cnt + 1;

                if r_cnt >= unsigned(i_max) - 1 then
                    o_roll <= '1';
                    r_cnt <= (others => '0');
                end if;
            end if;
        end if;
    end process p_count;

    o_cnt <= std_logic_vector(r_cnt);

end architecture rtl;
