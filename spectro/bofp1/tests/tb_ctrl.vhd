
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.stop;

entity tb_ctrl is
    generic (
        G_CTRL_WIDTH: integer := 16;
        G_CLK_FREQ: integer := 100_000_000;
        G_SCLK_FREQ: integer := 38_000_000
    );
end entity tb_ctrl;

architecture bhv of tb_ctrl is
    signal r_clk: std_logic := '0';
    signal r_rst_n: std_logic := '0';
    signal r_async_rd_rdy: std_logic := '0';
    signal r_async_rd_data: std_logic_vector(G_CTRL_WIDTH-1 downto 0);
    signal r_async_rd_en: std_logic;
    signal r_ccd_sample: std_logic;

    signal r_sclk: std_logic := '0';
    signal r_sen: std_logic := '0';
    signal r_sdata_rdy: std_logic := '0';
    signal r_sdata_i: std_logic_vector(G_CTRL_WIDTH-1 downto 0);
    signal r_sdata_o: std_logic_vector(G_CTRL_WIDTH-1 downto 0);
    signal r_sasync_wr_en: std_logic;
    signal r_sasync_wr_data: std_logic_vector(G_CTRL_WIDTH-1 downto 0);
    signal r_sfifo_rd_en: std_logic;
    signal r_sfifo_rd_data: std_logic_Vector(G_CTRL_WIDTH-1 downto 0);

    constant c_clk_period: time := (1.0 / real(G_CLK_FREQ)) * (1 sec);
    constant c_sclk_period: time := (1.0 / real(G_SCLK_FREQ)) * (1 sec);

    constant c_reg_read: integer := 0;
    constant c_reg_sample: integer := 1;
begin
    r_clk <= not r_clk after c_clk_period / 2;
    r_sclk <= not r_sclk after c_sclk_period / 2;
    r_rst_n <= '1' after c_clk_period * 2;

    u_ctrl: entity work.ctrl(behaviour) generic map(
        G_CTRL_WIDTH => G_CTRL_WIDTH
    )
    port map(
        i_clk => r_clk,
        i_rst_n => r_rst_n,
        i_async_rd_rdy => r_async_rd_rdy,
        i_async_rd_data => r_async_rd_data,
        o_async_rd_en => r_async_rd_en,
        o_ccd_sample => r_ccd_sample,

        i_s_clk => r_sclk,
        i_s_en => r_sen,
        i_s_data_rdy => r_sdata_rdy,
        i_s_data => r_sdata_i,
        o_s_data => r_sdata_o,
        o_s_async_wr_en => r_sasync_wr_en,
        o_s_async_wr_data => r_sasync_wr_data,

        o_s_fifo_rd_en => r_sfifo_rd_en,
        i_s_fifo_rd_data => r_sfifo_rd_data
    );

    -- Mimic the FIFO that transfers data from the SPI clock domain to the
    -- main clock domain
    p_sync_ctrl: process
    begin
        if r_rst_n = '0' then
            wait until r_rst_n = '1';
        end if;

        wait until r_sasync_wr_en = '1';
        r_async_rd_data <= r_sasync_wr_data;

        -- "Random" delay between writing and reading, as realistically this
        -- does not happen on the same clock
        wait for c_clk_period * 0.5;

        r_async_rd_rdy <= '1';
        wait for c_clk_period;
        r_async_rd_rdy <= '0';
    end process p_sync_ctrl;

    -- Mimic the sample FIFO
    p_fifo: process
        variable v_val: unsigned(G_CTRL_WIDTH-1 downto 0) := (others => '0');
    begin
        v_val := v_val + 1;

        wait until r_sfifo_rd_en = '1';
        r_sfifo_rd_data <= std_logic_vector(v_val);
    end process p_fifo;

    p_main: process
        procedure put_data(
            constant data: in std_logic_vector(G_CTRL_WIDTH-1 downto 0)) is
        begin
            r_sdata_i <= data;
            r_sdata_rdy <= '1';
            wait for c_sclk_period;
            r_sdata_rdy <= '0';
        end procedure put_data;

        procedure put_reg(constant reg: in integer) is
        begin
            put_data(std_logic_vector(to_unsigned(reg, 4)) & "000000000000");
        end procedure put_reg;
    begin
        wait until r_rst_n = '1';

        -- Enable sub (like pull down chip select)
        r_sen <= '1';
        wait until rising_edge(r_sclk);
        put_reg(c_reg_read);

        wait for c_sclk_period * 2;

        for i in 1 to 15 loop
            assert to_integer(unsigned(r_sdata_o)) = i
            report "Readout should be "
                & integer'image(i) & ", is "
                & integer'image(to_integer(unsigned(r_sdata_o)))
            severity failure;

            wait for c_sclk_period * 16;
        end loop;

        -- CS reset
        r_sen <= '0';
        wait for c_sclk_period;
        r_sen <= '1';

        put_reg(c_reg_sample);
        wait until r_ccd_sample = '1' for c_sclk_period + c_clk_period * 4;

        assert r_ccd_sample = '1'
        report "CCD sample should be set" severity failure;
        wait until r_ccd_sample = '0' for c_clk_period * 1.05;
        assert r_ccd_sample = '0'
        report "CCD sample should be cleared" severity failure;

        wait for c_sclk_period * 3;
        
        stop;
    end process p_main;

end architecture bhv;
