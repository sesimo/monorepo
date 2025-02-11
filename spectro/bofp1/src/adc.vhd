
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package p_ads8329 is
    type t_pins is record
        i_stconv: std_logic;
        o_eoc: std_logic;
    end record t_pins;
end package p_ads8329;

entity ads8329 is
    generic (
        G_RESOLUTION: integer := 16;
        G_CLK_FREQ: integer := 100_000_000;
        G_MOD_FREQ: integer := 10_000_000
    );

    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_start: in std_logic;
        i_pins: in p_ads8329.t_pins;

        o_rdy: out std_logic;
        o_buf: out std_logic_vector(G_RESOLUTION-1 downto 0)
    );
end entity ads8329;

architecture rtl of ads8329 is
    type t_state is (S_IDLE, S_CONVERTING, S_READ);
    signal r_state: t_state;

    signal r_enable: std_logic;
    constant c_clk_div: integer := G_CLK_FREQ / G_MOD_FREQ;

    -- TODO: instantiate SPI
    -- spi port (
    --     i_clk => i_clk,
    --     i_rst_n => i_rst_n,
    --     i_enable => i_enable,
    --     o_active => o_active,
    --     o_buf => o_buf
    -- )

    -- Lines to ADC hardware
    signal o_stconv: std_logic;
    signal i_eoc_unsafe: std_logic;
    signal i_eoc: std_logic;

    -- SPI inputs
    signal o_spi_enable: std_logic;
    signal i_spi_active: std_logic;
begin
    -- Flip-flopped
    u_ff_eoc: entity work.ff(rtl) port map(
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_sig => i_eoc_unsafe,
        o_sig => i_eoc
    );

    -- Generate enable signal
    p_enable: process(i_clk, i_rst_n) 
        variable v_count: integer := 0;
    begin
        if i_rst_n = '0' then
            v_count := 0;
            r_enable <= '0';
        elsif rising_edge(i_clk) then
            if v_count = c_clk_div then
                v_count := 0;
                r_enable <= '1';
            else
                v_count := v_count + 1;
                r_enable <= '0';
            end if;
        end if;
    end process p_enable;

    -- State machine
    p_conv: process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_state <= S_IDLE;

            o_rdy <= '0';
            o_buf <= (others => '0');
            
            o_stconv <= '0';
            i_eoc <= '0';
        elsif rising_edge(i_clk) and r_enable = '1' then
            o_stconv <= '0';
            o_rdy <= '0';
            o_spi_enable <= '0';

            case r_state is
                when S_IDLE =>
                    -- Wait for start signal
                    if i_start = '1' then
                        o_stconv <= '1';
                        r_state <= S_CONVERTING;
                    end if;
                when S_CONVERTING =>
                    -- Started, wait for conversion to complete
                    if i_eoc = '1' then
                        o_spi_enable <= '1';
                        r_state <= S_READ;
                    end if;
                when S_READ =>
                    -- Conversion done, read out
                    if i_spi_active = '0' then
                        o_rdy <= '1';
                        r_state <= S_IDLE;
                    end if;
            end case;
        end if;
    end process p_conv;

end architecture rtl;
