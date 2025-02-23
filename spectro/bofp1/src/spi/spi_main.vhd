
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
        i_sclk: in std_logic;
        o_mosi: out std_logic;
        o_cs_n: out std_logic;
        
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rdy: out std_logic
    );
end entity spi_main;

architecture rtl of spi_main is
    signal r_cs_n_buf: std_logic;

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
            i_sclk => i_sclk,
            i_cs_n  => r_cs_n_buf,
            i_in => i_miso,
            o_out => o_mosi,

            i_data => i_data,
            o_data => o_data,

            o_sample_done => r_sample_done,
            o_shift_done => r_shift_done
        );

    p_handle_state: process(i_clk)
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
                        if i_start = '1' then
                            r_state <= S_STARTING;
                            r_cs_n_buf <= '0';
                        end if;
                    when S_STARTING =>
                        r_state <= S_RUNNING;
                    when S_RUNNING =>
                        if r_sample_done = '1' and r_shift_done = '1' then
                            r_state <= S_STOPPING;
                            r_cs_n_buf <= '1';
                        end if;
                    when S_STOPPING =>
                        o_rdy <= '1';
                        r_state <= S_IDLE;
                end case;
            end if;
        end if;
    end process p_handle_state;

end architecture rtl;
