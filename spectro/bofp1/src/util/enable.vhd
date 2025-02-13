
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
begin
    u_counter: entity work.counter(rtl) generic map (
        G_WIDTH => G_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_start => '1',
        i_cyc_cnt => i_clk_div,
        i_rst_n => i_rst_n,
        o_int => o_enable
    );
end architecture rtl;
