
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vivado.all;
use work.ctrl_common.all;

entity frame_fifo is
    generic (
        C_OVERFLOW: t_err;
        C_UNDERFLOW: t_err
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_wr: in std_logic;
        i_rd: in std_logic;
        i_data: in std_logic_vector(15 downto 0);
        o_data: out std_logic_vector(15 downto 0);
        o_full: out std_logic;
        o_empty: out std_logic;
        o_watermark: out std_logic;
        o_errors: out t_err_bitmap
    );
end entity frame_fifo;

architecture behaviour of frame_fifo is
    signal r_full: std_logic;
    signal r_empty: std_logic;
    signal r_wr_en: std_logic;
    signal r_rd_en: std_logic;
    signal r_rst: std_logic;
begin

    -- Vivado component
    u_fifo_data: fifo_data
        port map (
            clk => i_clk,
            rst => r_rst,
            wr_en => r_wr_en,
            din => i_data,
            rd_en => r_rd_en,
            dout => o_data,
            empty => r_empty,
            prog_full => o_watermark,
            full => r_full
        );

    -- Detect overflow/underflow errors
    p_err_detect: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n /= '0' then
                set_err(o_errors, C_OVERFLOW, '0');
                set_err(o_errors, C_UNDERFLOW, '0');

                if i_wr = '1' and r_full = '1' then
                    set_err(o_errors, C_OVERFLOW, '1');
                end if;

                if i_rd = '1' and r_empty = '1' then
                    set_err(o_errors, C_UNDERFLOW, '1');
                end if;
            end if;
        end if;
    end process p_err_detect;

    r_rst <= not i_rst_n;
    r_wr_en <= i_wr when not r_full else '0';
    r_rd_en <= i_rd when not r_empty else '0';
    o_full <= r_full;
    o_empty <= r_empty;

end architecture behaviour;
