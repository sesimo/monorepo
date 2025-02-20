
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_main is
    generic (
        G_MODE: integer range 0 to 3 := 1;
        G_DATA_WIDTH: integer := 8;

        G_CLK_DIV: integer := 2
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);

        i_miso: in std_logic;
        o_mosi: out std_logic;
        o_sclk: out std_logic;
        o_cs_n: out std_logic;
        
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rdy: out std_logic
    );
end entity spi_main;

architecture rtl of spi_main is
    signal r_sclk_buf: std_logic;
    signal r_sclk_rst_n: std_logic;
    signal r_cs_n_buf: std_logic;

    signal r_start_ext: std_logic;

    type t_state is (S_IDLE, S_STARTING, S_RUNNING, S_STOPPING);
    signal r_state: t_state;

    constant c_period: unsigned := to_unsigned(G_CLK_DIV, 8);
    constant c_pulse: unsigned := c_period / 2;

    -- Convert a boolean to std_logic '1' or '0'
    function f_bool_logic(b: in boolean) return std_logic is
    begin
        if b then
            return '1';
        end if;

        return '0';
    end function f_bool_logic;
begin
    o_sclk <= r_sclk_buf;
    r_sclk_rst_n <= f_bool_logic(not(i_rst_n = '0' or (r_state = S_IDLE)));
    
    o_cs_n <= r_cs_n_buf;

    -- Drive SCLK
    u_sclk: entity work.pwm(rtl)
        generic map (
            G_WIDTH => 8
        )
        port map (
            i_clk => i_clk,
            i_rst_n => r_sclk_rst_n,
            i_period => std_logic_vector(c_period),
            i_pulse => std_logic_vector(c_pulse),
            o_clk => r_sclk_buf
        );

    -- Common SPI entity, sampling in and shifting out
    u_spi_common: entity work.spi_common
        generic map(
            G_MODE => G_MODE,
            G_DATA_WIDTH => G_DATA_WIDTH
        )
        port map(
            i_sclk => r_sclk_buf,
            i_cs_n  => r_cs_n_buf,
            i_in => i_miso,
            o_out => o_mosi,

            i_data => i_data,
            o_data => o_data
        );

    -- Detect the start condition and prolong it for one SCLK cycle
    p_detect_start: process(i_clk)
        variable v_sclk_last: std_logic;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_start_ext <= '0';
            else
                if i_start = '1' then
                    r_start_ext <= '1';
                    v_sclk_last := '1';
                elsif r_sclk_buf /= v_sclk_last and r_sclk_buf = '1' then
                    -- Clear at next high edge of SCLK
                    r_start_ext <= '0';
                end if;

                v_sclk_last := r_sclk_buf;
            end if;
        end if;
    end process p_detect_start;

    p_handle_state: process(i_clk)
        variable v_cyc_cnt: integer;
        variable v_last: std_logic;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_cs_n_buf <= '1';
                o_rdy <= '0';
                r_state <= S_IDLE;
            else
                o_rdy <= '0';

                case r_state is
                    when S_IDLE =>
                        if r_start_ext = '1' then
                            r_state <= S_STARTING;
                            r_cs_n_buf <= '0';
                        end if;
                    when S_STARTING =>
                        r_state <= S_RUNNING;
                        v_cyc_cnt := 0;
                    when S_RUNNING =>
                        if r_sclk_buf = '0' and r_sclk_buf /= v_last then
                            v_cyc_cnt := v_cyc_cnt + 1;

                            if v_cyc_cnt >= G_DATA_WIDTH then
                                o_rdy <= '1';
                                r_state <= S_STOPPING;
                            end if;
                        end if;
                    when S_STOPPING =>
                        r_cs_n_buf <= '1';
                        r_state <= S_IDLE;
                end case;

                v_last := r_sclk_buf;
            end if;
        end if;
    end process p_handle_state;

end architecture rtl;
