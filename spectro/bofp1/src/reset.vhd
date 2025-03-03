
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset is
    generic (
        G_CYC_COUNT: integer
    );
    port (
        i_clk: in std_logic;
        i_en: in std_logic;

        o_rst: out std_logic
    );
end entity reset;

architecture rtl of reset is
    signal r_in_reset: boolean := false;
    signal r_count: integer range 0 to G_CYC_COUNT-1 := 0;
begin

    p_reset: process(i_clk) is
    begin
        if rising_edge(i_clk) then
            o_rst <= '1';

            if i_en = '1' then
                r_in_reset <= true;
                -- Enters reset now, will have been in reset for one cycle on
                -- next clock edge (when r_count will be checked)
                r_count <= 1;
            elsif r_in_reset then
                if r_count >= G_CYC_COUNT-1 then
                    r_in_reset <= false;
                else
                    r_count <= r_count + 1;
                end if;
            else
                o_rst <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
