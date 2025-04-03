
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_main is
    generic (
        G_DATA_WIDTH: integer := 8
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);

        i_miso: in std_logic;
        i_sclk2: in std_logic;
        o_mosi: out std_logic;
        o_cs_n: out std_logic;
        
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rdy: out std_logic
    );
end entity spi_main;

architecture rtl of spi_main is
    signal r_cs_n_buf: std_logic;

    signal r_sample_en: std_logic;
    signal r_shift_en: std_logic;

    signal r_sample_done: std_logic;
    signal r_shift_done: std_logic;

    type t_state is (S_IDLE, S_STARTING, S_RUNNING, S_STOPPING);
    signal r_state: t_state;
begin
    o_cs_n <= r_cs_n_buf;

    -- Common SPI entity, sampling in and shifting out
    u_spi_common: entity work.spi_common
        generic map(
            G_DATA_WIDTH => G_DATA_WIDTH
        )
        port map(
            i_clk => i_clk,
            i_rst_n => i_rst_n,

            i_sample_en => r_sample_en,
            i_shift_en => r_shift_en,

            i_in => i_miso,
            i_cs_n => r_cs_n_buf,
            o_out => o_mosi,

            i_data => i_data,
            o_data => o_data,

            o_sample_done => r_sample_done,
            o_shift_done => r_shift_done
        );

    -- Detect edge on SCLK signal. Because of difficulties detecting
    -- both rising and falling edge, this does not use the SCLK signal
    -- itself but instead a separate clock at twice the frequency of the
    -- SCLK signal. Every other rising edge then corresponds to rising
    -- or falling edge of the SCLK signal. Doing it this way should
    -- avoid having to route the SCLK signal outside the clock network.
    b_sclk_edge: block
        signal r_last: boolean := false;
        signal r_sclk: boolean := false;
        signal r_edge: boolean := false;
        signal r_mode: boolean := false;
    begin

        -- Flip the edge on every rising edge of SCLK2. Because SCLK2 is
        -- 2x faster than SCLK, the first rising edge will correspond to
        -- rising SCLK, and the second rising edge will correspond to falling
        -- SCLK. This repeats infinitely
        p_sclk: process(i_sclk2)
        begin
            if rising_edge(i_sclk2) then
                r_sclk <= not r_sclk;
            end if;
        end process p_sclk;

        -- Syncrhonize edge from SCLK2 to CLK domain. Because the two domains
        -- are synchronous no CDC is required, and the edge can then
        -- be determined by a difference between the CLK syncrhonized register
        -- and the register clocked by SCLK2.
        p_edge_sync: process(i_clk)
        begin
            if rising_edge(i_clk) then
                r_last <= r_sclk;
            end if;
        end process p_edge_sync;

        -- Edge has been updated, but CLK has not yet processed it.
        r_edge <= r_sclk /= r_last;

        -- Invert the mode on every SCLK edge detected. This tells what
        -- edge it is (falling or rising SCLK) to determine whether this
        -- is the sampling or shifting edge.
        p_mode: process(i_clk)
        begin
            if rising_edge(i_clk) then
                if r_edge then
                    r_mode <= not r_mode;
                end if;
            end if;
        end process p_mode;

        r_sample_en <= '1' when (r_mode and r_edge) else '0';
        r_shift_en <= '1' when (not r_mode and r_edge) else '0';

    end block b_sclk_edge;

    p_cs_n: process(r_state)
    begin
        case r_state is
            when S_RUNNING =>
                r_cs_n_buf <= '0';
            when others =>
                r_cs_n_buf <= '1';
        end case;
    end process p_cs_n;

    p_rdy: process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_rdy <= '0';

            if i_rst_n /= '0' and r_state = S_STOPPING then
                o_rdy <= '1';
            end if;
        end if;
    end process p_rdy;

    p_state: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_state <= S_IDLE;
            else
                case r_state is
                    when S_IDLE =>
                        if i_start = '1' then
                            r_state <= S_STARTING;
                        end if;
                    when S_STARTING =>
                        -- Pull CS low on the first falling edge detected
                        if r_sample_en = '1' then
                            r_state <= S_RUNNING;
                        end if;
                    when S_RUNNING =>
                        -- SPI is in mode 1, which means sampling on falling
                        -- edge. CS can then be raised again after that.
                        if r_sample_done = '1' then
                            r_state <= S_STOPPING;
                        end if;
                    when S_STOPPING =>
                        r_state <= S_IDLE;
                end case;
            end if;
        end if;
    end process p_state;

end architecture rtl;
