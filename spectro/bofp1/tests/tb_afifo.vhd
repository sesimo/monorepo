
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_afifo is
    generic (
        G_SIZE: integer := 4;
        G_WIDTH: integer := 8
    );
end entity tb_afifo;

architecture bhv of tb_afifo is
    signal r_rd_clk: std_logic := '0';
    signal r_rd_en: std_logic := '0';
    signal r_rd_empty: std_logic;
    signal r_rd_data: std_logic_vector(G_WIDTH-1 downto 0);

    signal r_wr_clk: std_logic := '0';
    signal r_wr_en: std_logic := '0';
    signal r_wr_full: std_logic;
    signal r_wr_data: std_logic_vector(G_WIDTH-1 downto 0);

    signal r_rst_n: std_logic := '0';

    function period(freq: integer) return time is
    begin
        return (1.0 / real(freq)) * (1 sec);
    end function period;

    constant c_rd_clk_period: time := period(50_000_000);
    constant c_wr_clk_period: time := period(37_000_00);
begin
    r_rd_clk <= not r_rd_clk after c_rd_clk_period / 2;
    r_wr_clk <= not r_wr_clk after c_wr_clk_period / 2;

    r_rst_n <= '1' after c_wr_clk_period * 1.2;

    u_fifo: entity work.afifo(rtl) generic map(
        G_SIZE => G_SIZE,
        G_DATA_WIDTH => G_WIDTH
    )
    port map (
        i_rd_clk => r_rd_clk,
        i_rd_rst_n => r_rst_n,
        i_rd_en => r_rd_en,
        o_rd_data => r_rd_data,
        o_rd_empty => r_rd_empty,

        i_wr_clk => r_wr_clk,
        i_wr_rst_n => r_rst_n,
        i_wr_en => r_wr_en,
        i_wr_data => r_wr_data,
        o_wr_full => r_wr_full
    );

    p_write: process
    begin
        wait until r_rst_n = '1';
        wait for c_wr_clk_period * 3;
        
        for i in 0 to 16 loop
            if r_wr_full /= '0' then
                wait until r_wr_full = '0';
            end if;

            r_wr_en <= '1';
            r_wr_data <= std_logic_vector(to_unsigned(i, G_WIDTH));
            wait for c_wr_clk_period/2;
            r_wr_en <= '0';
            wait for c_wr_clk_period/2;
        end loop;

        wait;
    end process p_write;

    p_read: process
    begin
        wait until r_rst_n = '1';
        wait for c_rd_clk_period * 3;
        
        for i in 0 to 16 loop
            if r_rd_empty /= '0' then
                wait until r_rd_empty = '0';
            end if;
            r_rd_en <= '1';
            wait for c_rd_clk_period/2;
            r_rd_en <= '0';
            wait for c_rd_clk_period/2;
        end loop;

        wait;
    end process p_read;

    p_main: process
    begin
        wait for 20000 ns;
        stop;
    end process p_main;

end architecture bhv;
