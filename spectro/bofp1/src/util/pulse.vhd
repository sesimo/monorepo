
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

entity pulse is
    generic (
        G_WIDTH: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_cyc_cnt: in std_logic_vector(G_WIDTH-1 downto 0);
        i_en: in std_logic;
        o_out: out std_logic
    );
end entity pulse;

architecture rtl of pulse is
    signal r_count: integer range 0 to int_max(G_WIDTH);
begin

    p_pulse: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                o_out <= '0';
                r_count <= 0;
            else
                r_count <= r_count + 1;

                if i_en = '1' then
                    r_count <= 1;
                    o_out <= '1';
                elsif r_count >= unsigned(i_cyc_cnt) then
                    o_out <= '0';
                    r_count <= 0;
                elsif r_count = 0 then
                    r_count <= 0;
                end if;
            end if;
        end if;
    end process p_pulse;

end architecture rtl;
