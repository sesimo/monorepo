
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.utils.all;
use work.vivado.all;

entity window_fifo is
    generic (
        C_SIZE: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_rd: in std_logic;
        i_wr: in std_logic;
        i_data: in std_logic_vector(15 downto 0);
        o_data: out std_logic_vector(15 downto 0)
    );
end entity window_fifo;

architecture behaviour of window_fifo is
    signal r_rst: std_logic;
    signal r_wr_en: std_logic;
    signal r_rd_en: std_logic;
    signal r_full: std_logic;
    signal r_empty: std_logic;
begin

    r_rst <= not i_rst_n;
    r_wr_en <= i_wr when not r_full else '0';
    r_rd_en <= i_rd when not r_empty else '0';

    g_256: if C_SIZE = 256 generate
        u_fifo: fifo_window_256
            port map(
                clk => i_clk,
                rst => r_rst,
                rd_en => r_rd_en,
                wr_en => r_wr_en,
                din => i_data,
                dout => o_data,
                full => r_full,
                empty => r_empty
            );
    end generate g_256;

    g_64: if C_SIZE = 64 generate
        u_fifo: fifo_window_64
            port map(
                clk => i_clk,
                rst => r_rst,
                rd_en => r_rd_en,
                wr_en => r_wr_en,
                din => i_data,
                dout => o_data,
                full => r_full,
                empty => r_empty
            );
    end generate g_64;

end architecture behaviour;
