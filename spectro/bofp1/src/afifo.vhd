
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity afifo is
    generic (
        G_SIZE: integer;
        G_DATA_WIDTH: integer
    );
    port (
        i_rd_clk: in std_logic;
        i_rd_rst_n: in std_logic;
        i_rd_en: in std_logic;
        o_rd_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rd_empty: out std_logic;

        i_wr_clk: in std_logic;
        i_wr_rst_n: in std_logic;
        i_wr_en: in std_logic;
        i_wr_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_wr_full: out std_logic
    );
end entity afifo;

architecture rtl of afifo is
    constant c_bits_needed: integer := integer(ceil(log2(real(G_SIZE))));

    function f_gray(n: in unsigned) return unsigned is
    begin
        return n xor (n sll 1);
    end function f_gray;

    signal r_rd_addr: unsigned(c_bits_needed-1 downto 0);
    signal r_wr_addr: unsigned(c_bits_needed-1 downto 0);
begin

end architecture rtl;
