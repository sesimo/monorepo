
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
        i_rd_en: in std_logic;
        i_data: in std_logic_vector(G_DATA_WIDTH-1 downto 0);

        i_miso: in std_logic;
        o_mosi: out std_logic;
        o_sclk: out std_logic;
        
        o_data: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rd_en: out std_logic
    );
end entity spi_main;

architecture rtl of spi_main is
    signal r_sclk_buf: std_logic;

    signal r_running: boolean;
    signal r_shifting: boolean;
    signal r_sampling: boolean;
    signal r_start_ext: std_logic;

    signal r_sample: std_logic;
    signal r_shift: std_logic;

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

    constant c_smpl_ris: std_logic := f_bool_logic(G_MODE = 0 or G_MODE = 3);
begin
    o_sclk <= r_sclk_buf;

    r_running <= r_start_ext = '1' or r_shifting or r_sampling;

    -- Drive SCLK
    u_sclk: entity work.pwm(rtl) generic map (
        G_WIDTH => 8
    )
    port map (
        i_clk => i_clk,
        i_rst_n => i_rst_n,
        i_period => std_logic_vector(c_period),
        i_pulse => std_logic_vector(c_pulse),
        o_clk => r_sclk_buf
    );

    -- Generate read enable signal for one clock cycle
    p_rd_en: process(i_clk)
        variable v_started: boolean;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                o_rd_en <= '0';
                v_started := false;
            else
                o_rd_en <= '0';

                if v_started and not r_running then
                    o_rd_en <= '1';
                    v_started := false;
                elsif r_start_ext = '1' then
                    v_started := true;
                end if;
            end if;
        end if;
    end process p_rd_en;

    -- Detect the start condition and prolong it for one SCLK cycle
    p_detect_start: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_start_ext <= '0';
            else
                if i_rd_en = '1' then
                    r_start_ext <= '1';
                elsif r_sclk_buf = '1' then
                    -- Clear at next high edge of SCLK
                    r_start_ext <= '0';
                end if;
            end if;
        end if;
    end process p_detect_start;

    p_enable: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_sample <= '0';
                r_shift <= '0';
            elsif r_running then
                -- In mode 0 and 3 (when CPOL=CPHA) sampling is done on the
                -- rising edge. -- In mode 1 and 2 (when CPOL!=CPHA) sampling
                -- is done on the falling edge. This gives that sampling is
                -- done when on the first cycle where sclk = (cpol = cpha).
                -- 
                -- This can be reduced to the below statement.
                r_sample <= f_bool_logic(
                    (r_sclk_buf = c_smpl_ris) and r_sample = '0');

                r_shift <= f_bool_logic(
                    (r_sclk_buf /= c_smpl_ris) and r_shift = '0');

            end if;
        end if;
    end process p_enable;

    p_sample: process(i_clk)
        variable v_shf_buf: std_logic_vector(i_data'range);
        variable v_count: integer;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                v_count := 0;
                v_shf_buf := (others => 'Z');

                r_sampling <= false;
            elsif r_sample = '1' then
                r_sampling <= true;

                v_shf_buf := i_miso & v_shf_buf(v_shf_buf'high downto 1);
                v_count := v_count + 1;

                if v_count >= G_DATA_WIDTH then
                    v_count := 0;
                    r_sampling <= false;
                    o_data <= v_shf_buf;
                end if;
            end if;
        end if;
    end process p_sample;

    p_shift: process(i_clk)
        variable v_shf_buf: std_logic_vector(i_data'range);
        variable v_count: integer;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                v_count := 0;
                v_shf_buf := (others => 'X');

                r_shifting <= false;
                o_mosi <= 'X';
            elsif r_shift = '1' then
                r_shifting <= true;

                -- Wait for start condition
                if v_count = 0 then
                    v_shf_buf := i_data;
                end if;

                v_count := v_count + 1;
                o_mosi <= v_shf_buf(0);

                v_shf_buf := "Z" & v_shf_buf(v_shf_buf'high downto 1);

                -- Complete
                if v_count >= G_DATA_WIDTH then
                    v_count := 0;
                    r_shifting <= false;
                end if;
            end if;
        end if;
    end process p_shift;

end architecture rtl;
