
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tcd1304 is
    generic (
        G_SH_CYC_NS: integer := 1000;
        G_ICG_HOLD_NS: integer := 2000;
        G_SH_DELAY_CYC: integer := 32;
        G_CLK_DATA_FREQ_DIV: integer := 4;
        G_NUM_ELEMENTS: integer := 3694;
        G_MCLK_DIV_WIDTH: integer := 11;

        G_CLK_FREQ: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_psc_div: in std_logic_vector(4 downto 0);
        i_mclk_div: in std_logic_vector(2 downto 0);
        i_sh_div: in std_logic_vector(7 downto 0);

        o_pin_sh: out std_logic;
        o_pin_icg: out std_logic;
        o_pin_mclk: out std_logic;
        o_ccd_busy: out std_logic;
        o_data_rdy: out std_logic
    );
end entity tcd1304;

architecture rtl of tcd1304 is
    type t_state is (S_IDLE, S_SYNCING, S_STARTING, S_CAPTURE);
    signal r_state: t_state;

    constant c_sh_pulse: integer := G_SH_CYC_NS / (1_000_000_000 / G_CLK_FREQ);
    constant c_icg_cyc: integer := G_ICG_HOLD_NS / (1_000_000_000 / G_CLK_FREQ);

    constant c_mclk_div_lowest: integer := G_CLK_FREQ / 4_000_000;
    constant c_mclk_div_highest: integer := G_CLK_FREQ / 800_000;
    constant c_mclk_div_diff: integer := (
        (c_mclk_div_highest - c_mclk_div_lowest) / 7
    );

    signal r_icg_buf: std_logic;

    signal r_mclk_buf: std_logic;
    signal r_mclk_cnt: std_logic_vector(G_MCLK_DIV_WIDTH-1 downto 0);
    signal r_mclk_pulse: std_logic_vector(G_MCLK_DIV_WIDTH-1 downto 0);
    signal r_mclk_en: std_logic;

    signal r_psc_en: std_logic;
    signal r_psc_div: std_logic_vector(i_psc_div'high+1 downto 0);

    signal r_sh_en: std_logic;
    signal r_sh_delayed: std_logic;
    signal r_sh_shf: std_logic_vector(G_SH_DELAY_CYC-1 downto 0);
    signal r_sh_buf: std_logic;
    signal r_sh_div: std_logic_vector(i_sh_div'high+1 downto 0);

    signal r_data_enable: std_logic;
    signal r_data_rst_n: std_logic;

    signal r_rd_count: integer range 0 to G_NUM_ELEMENTS;
begin
    o_pin_icg <= r_icg_buf;
    o_pin_mclk <= r_mclk_buf;
    o_pin_sh <= r_sh_delayed;
    o_data_rdy <= r_data_enable;

    r_psc_div <= std_logic_vector(resize(
                 unsigned(i_psc_div) + 1, r_psc_div'length));
    r_sh_div <= std_logic_vector(resize(
                 unsigned(i_sh_div) + 1, r_sh_div'length));

    -- Adjust the MCLK count value and pulse width
    p_mclk_adjust: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_mclk_cnt <= (others => '1');
                r_mclk_pulse <= (others => '1');
            else
                r_mclk_cnt <= std_logic_vector(to_unsigned(
                    c_mclk_div_lowest +
                        c_mclk_div_diff * to_integer(unsigned(i_mclk_div)),
                    G_MCLK_DIV_WIDTH
                ));

                r_mclk_pulse <= std_logic_vector(resize(
                    unsigned(r_mclk_cnt) srl 1,
                    G_MCLK_DIV_WIDTH
                ));
            end if;
        end if;
    end process p_mclk_adjust;

    -- Counter for the master clock. This triggers a one-cycle enable
    -- signal continously
    u_counter_mclk: entity work.counter(rtl)
        generic map(
            G_WIDTH => G_MCLK_DIV_WIDTH
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => '1',
            i_cyc_cnt => r_mclk_cnt,
            o_int => r_mclk_en
        );
    
    -- Generate pulse for output master clock
    u_pulse_mclk: entity work.pulse(rtl)
        generic map(
            G_WIDTH => G_MCLK_DIV_WIDTH
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => r_mclk_en,
            i_cyc_cnt => r_mclk_pulse,
            o_out => r_mclk_buf
        );

    -- Counter for the prescaler
    u_counter_psc: entity work.counter(rtl)
        generic map(
            G_WIDTH => 6
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => r_mclk_en,
            i_cyc_cnt => r_psc_div,
            o_int => r_psc_en
        );

    -- Counter for SH signal
    u_counter_sh: entity work.counter(rtl)
        generic map(
            G_WIDTH => 9
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => r_psc_en,
            i_cyc_cnt => r_sh_div,
            o_int => r_sh_en
        );

    -- Generate shift signal
    -- The integration time is determined by the periodicity of the
    -- shift pin. The pulse width of the shift should
    -- always be 1000 ns.
    u_pulse_sh: entity work.pulse(rtl)
        generic map(
            G_WIDTH => 10
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => r_sh_en,
            i_cyc_cnt => std_logic_vector(to_unsigned(c_sh_pulse, 10)),
            o_out => r_sh_buf
        );

    -- Delay shift signal
    p_sh_delay: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_sh_shf <= (others => '0');
                r_sh_delayed <= '0';
            else
                r_sh_delayed <= r_sh_shf(r_sh_shf'high);
                r_sh_shf <= r_sh_shf(r_sh_shf'high-1 downto 0) & r_sh_buf;
            end if;
        end if;
    end process p_sh_delay;

    -- Generate enable signal at the rate of the data signal.
    -- This is used to tigger sampling of the ADC, as well as incrementing
    -- the counter in `p_capture`.
    u_data_enable: entity work.enable(rtl) generic map(
        G_WIDTH => 10
    )
    port map(
        i_clk => i_clk,
        i_rst_n => r_data_rst_n,
        i_en => r_mclk_en,
        i_cyc_cnt => std_logic_vector(to_unsigned(G_CLK_DATA_FREQ_DIV, 10)),
        o_enable => r_data_enable
    );

    -- Reset when not capturing
    r_data_rst_n <= '0' when (i_rst_n = '0' or r_state /= S_CAPTURE) else '1';

    p_state: process(i_clk)
        variable v_count: integer range 0 to c_icg_cyc;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_icg_buf <= '0';
                r_state <= S_IDLE;
                r_rd_count <= 0;
            else
                case r_state is
                    when S_IDLE =>
                        r_icg_buf <= '0';
                        o_ccd_busy <= '0';

                        if i_start = '1' then
                            r_state <= S_SYNCING;
                            o_ccd_busy <= '1';
                        end if;

                    when S_SYNCING =>
                        -- Sync to the next rising edge of the shift
                        -- signal (before delay)
                        if r_sh_en = '1' then
                            r_icg_buf <= '1';
                            r_state <= S_STARTING;
                            v_count := 0;
                        end if;

                    when S_STARTING =>
                        if v_count >= c_icg_cyc then
                            r_icg_buf <= '0';
                            r_state <= S_CAPTURE;
                        else
                            v_count := v_count + 1;
                        end if;

                    when S_CAPTURE =>
                        if r_rd_count >= G_NUM_ELEMENTS then
                            r_rd_count <= 0;
                            r_state <= S_IDLE;
                        elsif r_data_enable then
                            r_rd_count <= r_rd_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process p_state;

end architecture rtl;
