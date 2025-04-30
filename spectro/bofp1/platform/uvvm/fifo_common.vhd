
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use uvvm_util.data_fifo_pkg.all;

entity fifo_common is
    generic (
        G_DATA_WIDTH: integer := 16;
        G_PROG_FULL: integer := 1;
        G_SIZE: integer;
        C_FWT: boolean := true
    );
    port (
        rst: in std_logic;
        wr_clk: in std_logic;
        rd_clk: in std_logic;
        din: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        wr_en: in std_logic;
        rd_en: in std_logic;
        dout: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        full: out std_logic;
        empty: out std_logic;
        prog_full: out std_logic
    );
end entity fifo_common;

architecture bhv of fifo_common is
    signal r_fifo: integer;

    signal r_count: natural range 0 to 16384;
    signal r_wr_count: integer;
    signal r_rd_count: integer;
begin
    r_fifo <= uvvm_fifo_init(G_DATA_WIDTH * G_SIZE);

    p_count: process(wr_clk, rst)
    begin
        if rst = '1' then
            r_count <= 0;
        elsif rising_edge(wr_clk) then
            r_count <= uvvm_fifo_get_count(r_fifo);
        end if;
    end process p_count;

    p_full: process(wr_clk, rst)
    begin
        if rst = '1' then
            full <= '0';
            prog_full <= '0';
        elsif rising_edge(wr_clk) then
            full <= '1' when uvvm_fifo_is_full(r_fifo) else '0';
            prog_full <= '1' when uvvm_fifo_get_count(r_fifo) >= G_PROG_FULL
                         else '0';
        end if;
    end process p_full;

    p_empty: process(rd_clk, rst)
    begin
        if rst = '1' then
            empty <= '0';
        elsif rising_edge(rd_clk) then
            empty <= '1' when uvvm_fifo_get_count(r_fifo) = 0 else '0';
        end if;
    end process p_empty;

    p_put: process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if rst = '1' then
                r_wr_count <= 0;
            elsif wr_en = '1' then
                r_wr_count <= r_wr_count + 1;
                uvvm_fifo_put(r_fifo, din);
            end if;
        end if;
    end process p_put;

    p_get: process(rd_clk)
        variable v_fwt: boolean := false;
    begin
        if rising_edge(rd_clk) then
            if rst = '1' then
                r_rd_count <= 0;
            elsif rd_en = '1' then
                dout <= uvvm_fifo_get(r_fifo, dout'length);

                if uvvm_fifo_get_count(r_fifo) = 0 then
                    v_fwt := false;
                end if;

                r_rd_count <= r_rd_count + 1;
            elsif C_FWT and not v_fwt and uvvm_fifo_get_count(r_fifo) = dout'length then
                v_fwt := true;
                dout <= uvvm_fifo_get(r_fifo, dout'length);

                r_rd_count <= r_rd_count + 1;
            end if;
        end if;
    end process p_get;

    p_rst: process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if rst = '1' then
                uvvm_fifo_flush(r_fifo);
            end if;
        end if;
    end process p_rst;

end architecture bhv;
