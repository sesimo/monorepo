
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tcd1304 is
    generic (
        G_CFG_WIDTH: integer := 8
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_shutter: in std_logic_vector(G_CFG_WIDTH-1 downto 0);
        i_clk_speed: in std_logic_vector(G_CFG_WIDTH-1 downto 0);

        o_pin_sh: out std_logic;
        o_pin_icg: out std_logic;
        o_pin_mclk: out std_logic
    );
end entity tcd1304;

architecture rtl of tcd1304 is
begin

end architecture rtl;
