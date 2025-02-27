
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

        G_CFG_WIDTH: integer;
        G_CLK_FREQ: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_sh_div: in std_logic_vector(G_CFG_WIDTH-1 downto 0);
        i_mclk_div: in std_logic_vector(G_CFG_WIDTH-1 downto 0);

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

    signal r_icg_buf: std_logic;
    signal r_mclk_buf: std_logic;

    signal r_sh_delayed: std_logic;
    signal r_sh_shf: std_logic_vector(G_SH_DELAY_CYC-1 downto 0);
    signal r_sh_buf: std_logic;

    signal r_data_enable: std_logic;
    signal r_data_rst_n: std_logic;

    signal r_rd_count: integer range 0 to G_NUM_ELEMENTS;
begin
    o_pin_icg <= r_icg_buf;
    o_pin_mclk <= r_mclk_buf;
    o_pin_sh <= r_sh_delayed;
    o_data_rdy <= r_data_enable;

    -- Generate shift signal
    -- The integration time is determined by the periodicity of the
    -- shift pin. The pulse width of the shift should
    -- always be 1000 ns.
    u_pwm_sh: entity work.pwm(rtl) generic map(
        G_WIDTH => G_CFG_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_period => i_sh_div,
        i_pulse => std_logic_vector(to_unsigned(c_sh_pulse, G_CFG_WIDTH)),
        o_clk => r_sh_buf
    );

    -- Generate master clock signal
    u_pwm_mclk: entity work.pwm(rtl) generic map(
        G_WIDTH => G_CFG_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_period => i_mclk_div,
        i_pulse => std_logic_vector(unsigned(i_mclk_div) / 2),
        o_clk => r_mclk_buf
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
        G_WIDTH => G_CFG_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_clk_div => std_logic_vector(
            resize(unsigned(i_mclk_div) * G_CLK_DATA_FREQ_DIV, G_CFG_WIDTH)),
        i_rst_n => r_data_rst_n,
        o_enable => r_data_enable
    );

    r_data_rst_n <= '0' when (i_rst_n = '0' or r_state /= S_CAPTURE) else '1';

    p_state: process(i_clk)
        variable v_last: std_logic;

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
                            v_last := r_sh_buf;
                            o_ccd_busy <= '1';
                        end if;

                    when S_SYNCING =>
                        -- Sync to the next rising edge of the shift
                        -- signal (before delay)
                        if r_sh_buf /= v_last and r_sh_buf = '1' then
                            r_icg_buf <= '1';
                            r_state <= S_STARTING;
                            v_count := 0;
                        end if;

                        v_last := r_sh_buf;

                    when S_STARTING =>
                        if v_count >= c_icg_cyc then
                            r_icg_buf <= '0';
                            r_state <= S_CAPTURE;
                        end if;

                        v_count := v_count + 1;

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
