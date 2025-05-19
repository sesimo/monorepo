
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity fifo_window_64 is
    port (
        rst: in std_logic;
        clk: in std_logic;
        din: in std_logic_vector(15 downto 0);
        wr_en: in std_logic;
        rd_en: in std_logic;
        dout: out std_logic_vector(15 downto 0);
        full: out std_logic;
        empty: out std_logic
    );
end entity fifo_window_64;

architecture bhv of fifo_window_64 is
begin
    u_fifo: entity work.fifo_common(bhv)
        generic map(
            G_DATA_WIDTH => 16,
            G_SIZE => 64,
            C_FWT => false
        )
        port map(
            rst => rst,
            wr_clk => clk,
            rd_clk => clk,
            din => din,
            wr_en => wr_en,
            rd_en => rd_en,
            dout => dout,
            full => full,
            empty => empty
        );
end architecture bhv;
