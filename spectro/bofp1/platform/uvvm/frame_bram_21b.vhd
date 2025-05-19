
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_bram_21b is
    port (
        clka: in std_logic;
        addra: in std_logic_vector(11 downto 0);
        rsta: in std_logic;
        wea: in std_logic;
        dina: in std_logic_vector(20 downto 0);
        douta: out std_logic_vector(20 downto 0);
        rsta_busy: out std_logic
    );
end entity frame_bram_21b;

architecture behaviour of frame_bram_21b is
begin

    u_wrap: entity work.frame_bram
        generic map(
            C_WIDTH => 21
        )
        port map(
            clka => clka,
            rsta => rsta,
            addra => addra,
            wea => wea,
            dina => dina,
            douta => douta,
            rsta_busy => rsta_busy
        );

end architecture behaviour;
