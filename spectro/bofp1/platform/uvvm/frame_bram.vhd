
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_bram is
    generic (
        C_WIDTH: integer;
        C_SIZE: integer := 3694
    );
    port (
        clka: in std_logic;
        addra: in std_logic_vector(11 downto 0);
        rsta: in std_logic;
        wea: in std_logic;
        dina: in std_logic_vector(C_WIDTH-1 downto 0);
        douta: out std_logic_vector(C_WIDTH-1 downto 0);
        rsta_busy: out std_logic
    );
end entity frame_bram;

architecture behaviour of frame_bram is
    type t_arr is array(C_SIZE-1 downto 0) of std_logic_vector(C_WIDTH-1 downto 0);
    signal r_arr: t_arr;
begin

    p_write: process(clka)
    begin
        if rising_edge(clka) then
            if wea = '1' then
                r_arr(to_integer(unsigned(addra))) <= dina;
            end if;
        end if;
    end process p_write;

    p_read: process(all)
    begin
        if addra = (addra'range => 'U') then
            douta <= (others => '0');
        else
            douta <= r_arr(to_integer(unsigned(addra)));
        end if;
    end process p_read;


end architecture behaviour;
