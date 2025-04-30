
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
        i_flush: in std_logic;
        i_sh_div: in std_logic_vector(23 downto 0);

        i_adc_eoc: in std_logic;
        o_adc_stconv: out std_logic;
        i_adc_sclk2: in std_logic;
        o_adc_mosi: out std_logic;
        i_adc_miso: in std_logic;
        o_adc_cs_n: out std_logic;

        o_pin_sh: out std_logic;
        o_pin_icg: out std_logic;
        o_pin_mclk: out std_logic;

        o_busy: out std_logic;
        o_data_rdy: out std_logic;
        o_data: out std_logic_vector(15 downto 0)
    );
end entity tcd1304;

architecture rtl of tcd1304 is
    type t_state is (S_IDLE, S_SYNCING, S_ICG, S_CAPTURE);
    signal r_state: t_state;

    constant c_sh_pulse: integer := G_SH_CYC_NS / (1_000_000_000 / G_CLK_FREQ);
    constant c_icg_cyc: integer := G_ICG_HOLD_NS / (1_000_000_000 / G_CLK_FREQ);

    constant c_mclk_count: integer := G_CLK_FREQ / 800_000;
    constant c_mclk_pulse: integer := c_mclk_count / 2;

    signal r_flush: boolean;

    signal r_icg_buf: std_logic;

    signal r_mclk_buf: std_logic;
    signal r_mclk_en: std_logic;

    signal r_sh_en: std_logic;
    signal r_sh_delayed: std_logic;
    signal r_sh_shf: std_logic_vector(G_SH_DELAY_CYC-1 downto 0);
    signal r_sh_buf: std_logic;
    signal r_sh_div: std_logic_vector(i_sh_div'high+1 downto 0);

    signal r_data_enable: std_logic;
    signal r_data_rst_n: std_logic;
    signal r_data_read: std_logic;

    signal r_adc_done: std_logic;

    signal r_pix_cnt: std_logic_vector(11 downto 0);
    signal r_cnt_rolled: std_logic;
    signal r_icg_rolled: std_logic;

    constant c_first: unsigned(11 downto 0) := to_unsigned(32, 12);
    constant c_last: unsigned(11 downto 0) := to_unsigned(G_NUM_ELEMENTS-16, 12);
begin
    r_sh_div <= std_logic_vector(resize(
                 unsigned(i_sh_div) + 1, r_sh_div'length));

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
            i_max => std_logic_vector(to_unsigned(c_mclk_count, G_MCLK_DIV_WIDTH)),
            o_roll => r_mclk_en
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
            i_cyc_cnt => std_logic_vector(to_unsigned(c_mclk_pulse, G_MCLK_DIV_WIDTH)),
            o_out => r_mclk_buf
        );

    -- Counter for SH signal
    u_counter_sh: entity work.counter(rtl)
        generic map(
            G_WIDTH => r_sh_div'length
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => r_mclk_en,
            i_max => r_sh_div,
            o_roll => r_sh_en
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

    -- Hold data enable in reset when not in capture state. This ensures
    -- that the count starts correctly next time.
    r_data_rst_n <= '0' when (i_rst_n = '0' or r_state /= S_CAPTURE) else '1';

    u_adc: entity work.ads8329(rtl) port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_start => r_data_read,

        i_pin_eoc => i_adc_eoc,
        o_pin_stconv => o_adc_stconv,

        i_miso => i_adc_miso,
        i_sclk2 => i_adc_sclk2,
        o_mosi => o_adc_mosi,
        o_cs_n => o_adc_cs_n,

        o_data => o_data,
        o_rdy => r_adc_done
    );

    -- Count number of pixels read out from the ADC
    u_pix_cnt: entity work.counter
        generic map(
            G_WIDTH => 12
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => r_adc_done,
            i_max => std_logic_vector(to_unsigned(G_NUM_ELEMENTS, 12)),
            o_cnt => r_pix_cnt,
            o_roll => r_cnt_rolled
        );

    -- Counter to ensure that ICG is held long enough
    u_icg_cnt: entity work.counter
        generic map(
            G_WIDTH => 9
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,
            i_en => r_icg_buf,
            i_max => std_logic_vector(to_unsigned(c_icg_cyc, 9)),
            o_roll => r_icg_rolled
        );

    p_flush: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_flush <= false;
            elsif i_flush = '1' then
                r_flush <= true;
            elsif r_flush and r_state = S_IDLE then
                r_flush <= false;
            end if;
        end if;
    end process p_flush;

    p_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_IDLE;
            else
                case r_state is
                    when S_IDLE =>
                        if i_start = '1' or i_flush = '1' then
                            r_state <= S_SYNCING;
                        end if;

                    when S_SYNCING =>
                        -- Sync to the next rising edge of the shift
                        -- signal (before delay)
                        if r_sh_en = '1' then
                            r_state <= S_ICG;
                        end if;

                    when S_ICG =>
                        -- Wait for the ICG counter to roll over
                        if r_icg_rolled = '1' then
                            r_state <= S_CAPTURE;
                        end if;

                    when S_CAPTURE =>
                        -- Wait for pixel counter to roll over
                        if r_cnt_rolled = '1' then
                            r_state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process p_state;

    -- Only drive the ready signal when reading an effective element
    -- (not dummy element), and not when flushing.
    p_rdy: process(all)
    begin
        if i_rst_n = '0' then
            o_data_rdy <= '0';
        elsif not r_flush then
            if unsigned(r_pix_cnt) >= c_first and unsigned(r_pix_cnt) < c_last then
                o_data_rdy <= r_adc_done;
            else
                o_data_rdy <= '0';
            end if;
        end if;
    end process p_rdy;

    r_data_read <= r_data_enable when r_state = S_CAPTURE else '0';
    r_icg_buf <= '1' when r_state = S_ICG else '0';
    o_busy <= '0' when (r_state = S_IDLE or r_flush) else '1';
    o_pin_icg <= r_icg_buf;
    o_pin_mclk <= r_mclk_buf;
    o_pin_sh <= r_sh_delayed;

end architecture rtl;
