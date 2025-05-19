
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vivado.all;

entity frame_ram is
    generic (
        C_WIDTH: integer := 16
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_wr_en: in std_logic;
        i_rd_en: in std_logic;
        i_addr: in std_logic_vector(11 downto 0);
        i_wr_data: in std_logic_vector(C_WIDTH-1 downto 0);
        o_rd_data: out std_logic_vector(C_WIDTH-1 downto 0)
    );
end entity frame_ram;

architecture behaviour of frame_ram is
    signal r_rst: std_logic;
    signal r_rd_data: std_logic_vector(o_rd_data'range);

    signal r_rd_en_tmp: std_logic;
    signal r_rd_en: std_logic;
begin
    r_rst <= not i_rst_n;

    g_ram: if C_WIDTH = 16 generate
        u_ram: frame_bram_16b
            port map(
                clka => i_clk,
                rsta => r_rst,
                wea => i_wr_en,
                addra => i_addr,
                dina => i_wr_data,
                douta => r_rd_data
            );
    elsif C_WIDTH = 21 generate
        u_ram: frame_bram_21b
            port map(
                clka => i_clk,
                rsta => r_rst,
                wea => i_wr_en,
                addra => i_addr,
                dina => i_wr_data,
                douta => r_rd_data
            );
    end generate g_ram;

    -- Vivado BRAM block updates douta whenever addra is changed, but we
    -- want to update it only when rd_en goes high.
    --
    -- The read delay on the Vivado BRAM is also 2 cycles, which means that
    -- we need to wait an extra 2 cycles before copying the data.
    p_read: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_rd_en_tmp <= i_rd_en;
            r_rd_en <= r_rd_en_tmp;

            if r_rd_en = '1' then
                o_rd_data <= r_rd_data;
            end if;
        end if;
    end process p_read;
end architecture behaviour;
