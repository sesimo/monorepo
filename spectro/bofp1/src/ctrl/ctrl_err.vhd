
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity ctrl_err is
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_clear: in std_logic;
        i_rising: in t_err_bitmap;
        o_persisted: out t_err_bitmap
    );
end entity ctrl_err;

architecture behaviour of ctrl_err is
    signal r_errors: t_err_bitmap;
begin

    p_set: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' or i_clear = '1' then
                r_errors <= (others => '0');
            else
                r_errors <= r_errors or i_rising;
            end if;
        end if;
    end process p_set;

    o_persisted <= r_errors;

end architecture behaviour;
