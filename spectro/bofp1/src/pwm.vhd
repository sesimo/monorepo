
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm is
    generic (
        G_CFG_WIDTH: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_period: in std_logic_vector(G_CFG_WIDTH-1 downto 0);
        i_pulse: in std_logic_vector(G_CFG_WIDTH-1 downto 0);
        
        o_clk: out std_logic
    );
end entity pwm;

architecture rtl of pwm is
begin

end architecture rtl;
