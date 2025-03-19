
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ads8329 is
    generic (
        G_STCONV_HOLD_CYC: integer := 10
    );

    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;

        i_pin_eoc: in std_logic;
        o_pin_stconv: inout std_logic;

        i_miso: in std_logic;
        i_sclk: in std_logic;
        o_mosi: out std_logic;
        o_cs_n: out std_logic;

        o_data: out std_logic_vector(15 downto 0);
        o_rdy: out std_logic
    );
end entity ads8329;

architecture rtl of ads8329 is
    type t_state is (S_IDLE, S_START, S_CONVERTING);
    signal r_state: t_state;

    signal r_stconv_rise: std_logic;
    signal r_rd_en: std_logic;

    signal r_eoc: std_logic;
    signal r_cdc_eoc: std_logic;

    constant c_cmd_read: std_logic_vector(15 downto 0) := x"D000";
begin
    u_stconv_pulse: entity work.pulse(rtl)
        generic map(
            G_WIDTH => 8
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_cyc_cnt => std_logic_vector(to_unsigned(G_STCONV_HOLD_CYC, 8)),
            i_en => r_stconv_rise,
            o_out => o_pin_stconv
        );

    u_spi: entity work.spi_main(rtl)
        generic map(
            G_DATA_WIDTH => 16
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_start => r_rd_en,
            i_data => c_cmd_read,

            i_miso => i_miso,
            i_sclk => i_sclk,
            o_mosi => o_mosi,
            o_cs_n => o_cs_n,

            o_data => o_data,
            o_rdy => o_rdy
        );

    p_eoc: process(i_clk)
        variable v_last: std_logic;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_eoc <= '0';
                r_cdc_eoc <= '0';
                v_last := '0';
            else
                if r_eoc = '0' and v_last = '0' then
                    r_eoc <= r_cdc_eoc;
                else
                    r_eoc <= '0';
                end if;

                v_last := r_cdc_eoc;
                r_cdc_eoc <= i_pin_eoc;
            end if;
        end if;
    end process p_eoc;

    p_conv: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_IDLE;
                
                r_stconv_rise <= '0';
                r_rd_en <= '0';
            else 
                r_rd_en <= '0';
                r_stconv_rise <= '0';

                case r_state is
                    when S_IDLE =>
                        -- Wait for start signal
                        if i_start = '1' then
                            r_stconv_rise <= '1';

                            r_state <= S_START;
                        end if;
                    when S_START =>
                        -- Wait for EOC to go low, which indicates the ADC
                        -- is converting.
                        if r_eoc = '0' then
                            r_state <= S_CONVERTING;
                        end if;

                    when S_CONVERTING =>
                        -- Started, wait for conversion to complete
                        if r_eoc = '1' then
                            r_rd_en <= '1';

                            r_state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process p_conv;

end architecture rtl;
