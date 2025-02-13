
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tcd1304 is
    generic (
        G_SH_CYC_NS: integer := 1000;
        G_CLK_DATA_FREQ_DIV: integer := 4;
        G_NUM_ELEMENTS: integer := 3696;

        G_CFG_WIDTH: integer;
        G_CLK_FREQ: integer
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_shutter: in std_logic_vector(G_CFG_WIDTH-1 downto 0);
        i_clk_speed: in std_logic_vector(G_CFG_WIDTH-1 downto 0);

        o_pin_sh: out std_logic;
        o_pin_icg: out std_logic;
        o_pin_mclk: out std_logic;
        o_rdy: out std_logic
    );
end entity tcd1304;

architecture rtl of tcd1304 is
    type t_state is (S_IDLE, S_SYNCING, S_CAPTURE);
    signal r_state: t_state;

    constant c_sh_pulse: integer := G_SH_CYC_NS / (1_000_000_000 / G_CLK_FREQ);

    signal r_icg_buf: std_logic;
    signal r_mclk_buf: std_logic;

    signal r_data_enable: std_logic;
    signal r_data_rst_n: std_logic;

    signal r_rd_count: integer;
begin
    o_pin_icg <= r_icg_buf;
    o_pin_mclk <= r_mclk_buf;

    -- Generate shutter signal
    -- The integration time is determined by the periodicity of the
    -- electronic shutter pin. The pulse width of the shutter should
    -- always be 1000 ns.
    u_pwm_sh: entity work.pwm(rtl) generic map(
        G_WIDTH => G_CFG_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_period => i_shutter,
        i_pulse => std_logic_vector(to_unsigned(c_sh_pulse, G_CFG_WIDTH)),
        o_clk => o_pin_sh
    );

    -- Generate master clock signal
    u_pwm_mclk: entity work.pwm(rtl) generic map(
        G_WIDTH => G_CFG_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_period => i_clk_speed,
        i_pulse => std_logic_vector(unsigned(i_clk_speed) / 2),
        o_clk => r_mclk_buf
    );

    -- Generate enable signal at the rate of the data signal.
    -- This is used to tigger sampling of the ADC, as well as incrementing
    -- the counter in `p_capture`.
    u_data_enable: entity work.enable(rtl) generic map(
        G_WIDTH => G_CFG_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_clk_div => std_logic_vector(
            resize(unsigned(i_clk_speed) * G_CLK_DATA_FREQ_DIV, G_CFG_WIDTH)),
        i_rst_n => r_data_rst_n,
        o_enable => r_data_enable
    );

    -- Only trigger enable signals when actually capturing
    r_data_rst_n <= '0' when (i_rst_n = '0' or r_state /= S_CAPTURE) else '1';

    p_capture: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_icg_buf <= '0';
                r_state <= S_IDLE;
                r_rd_count <= 0;
            else
                case r_state is
                    when S_IDLE =>
                        o_rdy <= '1';
                        r_icg_buf <= '0';

                        if i_start = '1' then
                            r_state <= S_SYNCING;
                            o_rdy <= '0';
                            r_icg_buf <= '1';
                        end if;

                    when S_SYNCING =>
                        -- Use a seperate state to sync to the CCD master clock,
                        -- that is, wait until mclk is high before continuing.
                        -- This is done since the idle state needs to detect a
                        -- high `i_start` on the edge of `i_clk`, but everything
                        -- else should be synced to the mclk.
                        if r_mclk_buf = '1' then
                            r_state <= S_CAPTURE;
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
    end process p_capture;

end architecture rtl;
