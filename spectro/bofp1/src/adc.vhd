
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
    type t_conv_state is (S_IDLE, S_START, S_CONVERTING);
    signal r_conv_state: t_conv_state;

    type t_op_state is (S_INIT, S_NORMAL);
    signal r_op_state: t_op_state;

    signal r_config_done: boolean;

    signal r_stconv_rise: std_logic;
    signal r_rd_en: std_logic;

    signal r_eoc: std_logic;
    signal r_cdc_eoc: std_logic;

    signal r_data_rdy: std_logic;
    
    signal r_cmd: std_logic_vector(15 downto 0);
    signal r_cmd_wr: std_logic;
    signal r_cfg_cmd: std_logic_vector(15 downto 0);

    signal r_transfer_start: std_logic;

    signal r_stconv: std_logic;

    constant c_cmd_read: std_logic_vector(15 downto 0) := x"D000";
    constant c_cmd_write_cfr: std_logic_vector(3 downto 0) := x"E";
begin
    o_rdy <= r_data_rdy;
    r_cmd <= r_cfg_cmd when r_op_state = S_INIT else c_cmd_read;
    r_transfer_start <= r_cmd_wr when r_op_state = S_INIT else r_rd_en;
    o_pin_stconv <= '1' when r_op_state = S_INIT else r_stconv;

    u_stconv_pulse: entity work.pulse(rtl)
        generic map(
            G_WIDTH => 8
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_cyc_cnt => std_logic_vector(to_unsigned(G_STCONV_HOLD_CYC, 8)),
            i_en => r_stconv_rise,
            o_out => r_stconv
        );

    u_spi: entity work.spi_main(rtl)
        generic map(
            G_DATA_WIDTH => 16
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_start => r_transfer_start,
            i_data => r_cmd,

            i_miso => i_miso,
            i_sclk => i_sclk,
            o_mosi => o_mosi,
            o_cs_n => o_cs_n,

            o_data => o_data,
            o_rdy => r_data_rdy
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

    p_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_op_state <= S_INIT;
            elsif r_config_done then
                r_op_state <= S_NORMAL;
            end if;
        end if;
    end process p_state;

    p_config: process(i_clk)
        variable v_busy: boolean;
    begin
        if rising_edge(i_clk) then
            r_cmd_wr <= '0';

            if i_rst_n = '0' then
                v_busy := false;
                r_config_done <= false;
            elsif r_op_state = S_INIT then
                if not v_busy then
                    r_cfg_cmd(15 downto 12) <= c_cmd_write_cfr;
                    r_cfg_cmd(11 downto 0) <= (0 => '0', others => '1');

                    r_cmd_wr <= '1';
                    v_busy := true;
                elsif r_data_rdy = '1' then
                    r_config_done <= true;
                end if;
            end if;
        end if;
    end process p_config;

    p_conv: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_conv_state <= S_IDLE;
                
                r_stconv_rise <= '0';
                r_rd_en <= '0';
            elsif r_op_state = S_NORMAL then
                r_rd_en <= '0';
                r_stconv_rise <= '0';

                case r_conv_state is
                    when S_IDLE =>
                        -- Wait for start signal
                        if i_start = '1' then
                            r_stconv_rise <= '1';

                            r_conv_state <= S_START;
                        end if;
                    when S_START =>
                        -- Wait for EOC to go low, which indicates the ADC
                        -- is converting.
                        if r_eoc = '0' then
                            r_conv_state <= S_CONVERTING;
                        end if;

                    when S_CONVERTING =>
                        -- Started, wait for conversion to complete
                        if r_eoc = '1' then
                            r_rd_en <= '1';

                            r_conv_state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process p_conv;

end architecture rtl;
