-- Asynchronous FIFO implementation, based on Clifford E. Cummings' paper:
-- http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf
-- This FIFO is safe to use across two seperate clock domains, one for
-- writing and another for reading. For details on implementation see
-- Clifford's paper.

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
    -- One extra bit to keep track of the overflow. This is used to determine
    -- whether the fifo is full.
    constant c_bits_needed: integer := integer(ceil(log2(real(G_SIZE)))) + 1;

    -- Memory area for the FIFO
    subtype t_item is std_logic_vector(G_DATA_WIDTH-1 downto 0);
    type t_mem is array(0 to G_SIZE-1) of t_item;
    signal r_mem: t_mem;

    -- Not subtracted 1 as we are using one extra bit to track wrapping
    subtype t_addr is unsigned(c_bits_needed-1 downto 0);
    subtype t_addr_real is integer range 0 to G_SIZE-1;
    subtype t_gray_addr is std_logic_vector(c_bits_needed-1 downto 0);

    -- Convert n to its equivalent in gray encoding
    function to_gray(n: t_addr) return t_gray_addr is
    begin
        return std_logic_vector((n srl 1) xor n);
    end function to_gray;

    -- Strip of the leading overflow bit
    function addr_real(n: t_addr) return t_addr_real is
    begin
        return to_integer(n(n'high-1 downto 0));
    end function addr_real;

    -- Read and write address, each local to its corresponding clock domain
    signal r_rd_addr: t_addr_real;
    signal r_wr_addr: t_addr_real;

    -- Binary representation of addresses. These are only used internally
    -- by their respective clock domains
    signal r_rbin: t_addr;
    signal r_rbin_next: t_addr;
    signal r_wbin: t_addr;
    signal r_wbin_next: t_addr;

    -- The gray addresses available to the read clock domain.
    -- `r_rgray`, `r_rgray_next`, `r_wgray` and `r_wgray_next` are used
    -- internally by their -- respective clock domains, whereas
    -- `r_rgray_cdc` and `r_wgray_cdc` cross the
    -- clock domains to the write and read domains, respectively.
    signal r_rgray: t_gray_addr;
    signal r_rgray_next: t_gray_addr;
    signal r_wgray: t_gray_addr;
    signal r_wgray_next: t_gray_addr;
    signal r_wgray_cdc: t_gray_addr;
    signal r_rgray_cdc: t_gray_addr;

    signal r_wr_full: boolean;
    signal r_rd_empty: boolean;
begin
    r_rbin_next <= r_rbin + 1 when not r_rd_empty and i_rd_en = '1' else r_rbin;
    r_wbin_next <= r_wbin + 1 when not r_wr_full and i_wr_en = '1' else r_wbin;

    r_rgray_next <= to_gray(r_rbin_next);
    r_wgray_next <= to_gray(r_wbin_next);

    o_rd_empty <= '1' when r_rd_empty else '0';
    o_wr_full <= '1' when r_wr_full else '0';

    -- Cross clock domain with the write gray addr, into the reading side
    u_dff_gray_wr: entity work.cdc_vector(rtl) generic map (
        G_WIDTH => c_bits_needed
    )
    port map(
        i_clk => i_rd_clk,
        i_sig => r_wgray,
        o_sig => r_wgray_cdc
    );

    -- Cross clock domain with the read gray addr, into the writing side
    u_dff_gray_rd: entity work.cdc_vector(rtl) generic map (
        G_WIDTH => c_bits_needed
    )
    port map(
        i_clk => i_wr_clk,
        i_sig => r_rgray,
        o_sig => r_rgray_cdc
    );

    p_read: process(i_rd_clk)
    begin
        if rising_edge(i_rd_clk) and i_rd_en = '1' then
            o_rd_data <= r_mem(r_rd_addr);
        end if;
    end process p_read;

    p_write: process(i_wr_clk)
    begin
        if rising_edge(i_wr_clk) and i_wr_en = '1' then
            r_mem(r_wr_addr) <= i_wr_data;
        end if;
    end process p_write;

    -- Update read address to next
    p_rd_addr: process(i_rd_clk, i_rd_rst_n)
    begin
        if i_rd_rst_n = '0' then
            r_rbin <= (others => '0');
            r_rgray <= (others => '0');
            r_rd_addr <= 0;
        elsif rising_edge(i_rd_clk) then
            r_rbin <= r_rbin_next;
            r_rgray <= r_rgray_next;
            r_rd_addr <= addr_real(r_rbin_next);
        end if;
    end process p_rd_addr;

    -- Update write address to next
    p_wr_addr: process(i_wr_clk, i_wr_rst_n)
    begin
        if i_wr_rst_n = '0' then
            r_wbin <= (others => '0');
            r_wgray <= (others => '0');
            r_wr_addr <= 0;
        elsif rising_edge(i_wr_clk) then
            r_wbin <= r_wbin_next;
            r_wgray <= r_wgray_next;
            r_wr_addr <= addr_real(r_wbin_next);
        end if;
    end process p_wr_addr;

    -- The buffer is empty when the read address matches the write address,
    -- and full when the write address - read address = G_SIZE.
    -- See http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf
    -- for a description on how this is calculated using the gray encoded
    -- signals
    p_empty: process(i_rd_clk)
    begin
        if rising_edge(i_rd_clk) then
            if i_rd_rst_n = '0' then
                r_rd_empty <= true;
            else 
                r_rd_empty <= r_rgray_next = r_wgray_cdc;
            end if;
        end if;
    end process p_empty;

    p_full: process(i_wr_clk)
    begin
        if rising_edge(i_wr_clk) then
            if i_wr_rst_n = '0' then
                r_wr_full <= false;
            else 
                r_wr_full <= r_wgray_next = (
                    not r_rgray_cdc(r_rgray_cdc'high downto r_rgray_cdc'high-1)
                    & r_rgray_cdc(r_rgray_cdc'high-2 downto 0)
                );
            end if;
        end if;
    end process p_full;

end architecture rtl;
