
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity dark_current is
    generic (
        C_UNDERFLOW_THRESHOLD: integer := 300
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_calib: in std_logic;

        i_data: in std_logic_vector(15 downto 0);
        i_rdy: in std_logic;
        i_en: in std_logic;

        o_rdy: out std_logic;
        o_busy: out std_logic;
        o_data: out std_logic_vector(15 downto 0);
        o_errors: out t_err_bitmap
    );
end entity dark_current;

architecture behaviour of dark_current is
    type t_state is (S_IDLE, S_CALIB, S_LOAD, S_CALC, S_READY);
    signal r_state: t_state;

    signal r_wr_en: std_logic;
    signal r_rd_en: std_logic;

    signal r_addr: unsigned(11 downto 0);

    signal r_calib: boolean;

    signal r_loaded: std_logic_vector(15 downto 0);
    signal r_calced: unsigned(15 downto 0);
begin
    u_ram: entity work.frame_ram
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_addr => std_logic_vector(r_addr),
            i_wr_en => r_wr_en,
            i_rd_en => r_rd_en,
            i_wr_data => i_data,
            o_rd_data => r_loaded
        );

    p_calib_hold: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_calib = '1' then
                r_calib <= true;
            elsif r_state = S_CALIB and i_en = '0' then
                r_calib <= false;
            end if;
        end if;
    end process p_calib_hold;

    -- Calibration is simply performed by writing a frame into memory with
    -- the light source disabled.
    p_calib: process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_wr_en <= '0';

            if r_state = S_CALIB then
                r_wr_en <= i_rdy;
            end if;
        end if;
    end process p_calib;

    p_addr: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' or r_state = S_IDLE then
                r_addr <= (others => '0');
            elsif r_state = S_READY or (r_state = S_CALIB and r_wr_en = '1') then
                r_addr <= r_addr + 1;
            end if;
        end if;
    end process p_addr;

    r_rd_en <= '1' when (r_state = S_LOAD or r_state = S_IDLE) else '0';

    p_calc: process(i_clk)
    begin
        if rising_edge(i_clk) then
            set_err(o_errors, ERR_DC_UNDERFLOW, '0');

            if r_state = S_CALC then
                r_calced <= unsigned(i_data) - unsigned(r_loaded);

                if unsigned(r_loaded) > unsigned(i_data) then
                    -- A small difference, where the measured dark current
                    -- happens to be slightly higher than the measured value,
                    -- is treated as no light being present on the pixel.
                    if unsigned(i_data) + C_UNDERFLOW_THRESHOLD >= unsigned(r_loaded) then
                        r_calced <= (others => '0');
                    else
                        set_err(o_errors, ERR_DC_UNDERFLOW, '1');
                    end if;
                end if;
            end if;
        end if;
    end process p_calc;

    p_busy: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_busy <= i_en;
        end if;
    end process p_busy;

    p_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' or i_en = '0' then
                r_state <= S_IDLE;
            else
                case r_state is
                    when S_IDLE =>
                        if r_calib then
                            r_state <= S_CALIB;
                        elsif i_rdy = '1' then
                            r_state <= S_CALC;
                        end if;

                    when S_CALIB =>
                        -- Will be reset to IDLE when i_en is dropped
                        null;

                    when S_LOAD =>
                        if i_rdy = '1' then
                            r_state <= S_CALC;
                        end if;

                    when S_CALC =>
                        r_state <= S_READY;

                    when S_READY =>
                        -- Continue processing the next pixel
                        r_state <= S_LOAD;

                    when others => null;
                end case;
            end if;
        end if;
    end process p_state;

    o_rdy <= '1' when (r_state = S_READY) else '0';
    o_data <= std_logic_vector(r_calced);

end architecture behaviour;
