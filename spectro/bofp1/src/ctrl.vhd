
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ctrl is
    generic (
        G_CTRL_WIDTH: integer := 16;
        G_REG_WIDTH: integer := 4
    );
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        o_ccd_sample: out std_logic;
        
        -- Read data from the other clock domain
        i_async_rd_rdy: in std_logic;
        i_async_rd_data: in std_logic_vector(G_CTRL_WIDTH-1 downto 0);
        o_async_rd_en: out std_logic;

        -- SPI sub ports
        -- NOTE: These are in the SPI SCLK domain, and must only interact
        -- with the main clock domain through the async FIFO
        i_s_clk: in std_logic;
        i_s_en: in std_logic;
        i_s_data_rdy: in std_logic;
        i_s_data: in std_logic_vector(G_CTRL_WIDTH-1 downto 0);
        o_s_data: out std_logic_vector(G_CTRL_WIDTH-1 downto 0);

        -- Synchronize to the other clock domain
        o_s_async_wr_en: out std_logic;
        o_s_async_wr_data: out std_logic_vector(G_CTRL_WIDTH-1 downto 0);

        -- Read out from sample FIFO buffer
        o_s_fifo_rd_en: out std_logic;
        i_s_fifo_rd_data: in std_logic_vector(G_CTRL_WIDTH-1 downto 0)
    );
end entity ctrl;

architecture behaviour of ctrl is
    signal r_s_arst_n: std_logic;
    signal r_s_stread: boolean;
    signal r_s_reading: boolean;

    type t_reg is (
        REG_READ,
        REG_SAMPLE
    );
    
    function parse_reg(code: std_logic_vector(G_CTRL_WIDTH-1 downto 0))
    return t_reg is
        variable v_uval: unsigned(G_REG_WIDTH-1 downto 0);
    begin
        v_uval := unsigned(code(code'high downto code'high-v_uval'high));

        return t_reg'val(to_integer(v_uval)); 
    end function parse_reg;
begin

    -- Assert reset async, release sync
    r_s_arst_n <= i_rst_n when rising_edge(i_s_clk) or i_rst_n = '0';

    r_s_reading <= i_s_en = '1' and (r_s_reading or r_s_stread);

    o_s_data <= i_s_fifo_rd_data when r_s_reading;
    o_s_async_wr_data <= i_s_data;

    -- Handle control codes that are safe to handle in sub clock domain.
    -- If needed, these control codes are passed through the async
    -- channel (FIFO) and further handled by `p_handle`.
    p_s_handle: process(i_s_clk, r_s_arst_n)
        variable v_reg: t_reg;
    begin
        if r_s_arst_n = '0' then
            o_s_async_wr_en <= '0';
            r_s_stread <= false;
        elsif rising_edge(i_s_clk) then
            r_s_stread <= false;
            o_s_async_wr_en <= '0';

            if i_s_data_rdy = '1' then
                v_reg := parse_reg(i_s_data);

                case v_reg is
                    when REG_READ =>
                        r_s_stread <= true;
                    
                    when others =>
                        -- Pass the control sequence through the FIFO, so
                        -- that it can be processed by the main clock domain
                        o_s_async_wr_en <= '1';
                end case;
            end if;
        end if;
    end process p_s_handle;

    -- Pop data from the FIFO whenever we are reading
    p_s_read: process(i_s_clk, r_s_arst_n)
        variable v_count: integer;
    begin
        if r_s_arst_n = '0' then
            v_count := 0;
            o_s_fifo_rd_en <= '0';
        elsif rising_edge(i_s_clk) then
            o_s_fifo_rd_en <= '0';

            if r_s_reading then
                if v_count = 0 then
                    -- Pop from FIFO
                    o_s_fifo_rd_en <= '1';
                end if;

                v_count := v_count + 1;

                if v_count >= G_CTRL_WIDTH then
                    v_count := 0;
                end if;
            else
                v_count := 0;
            end if;
        end if;
    end process p_s_read;

    p_handle: process(i_clk)
        variable v_popping: boolean;
    begin
        if rising_edge(i_clk) then
            o_async_rd_en <= '0';
            o_ccd_sample <= '0';

            if i_rst_n = '0' then
                v_popping := false;
            else
                -- Pop from FIFO when data is ready, handle it in the next
                if v_popping then
                    v_popping := false;

                    -- Handle control/config
                    case parse_reg(i_async_rd_data) is
                        when REG_SAMPLE =>
                            o_ccd_sample <= '1';

                        when others => null; 
                    end case;
                elsif i_async_rd_rdy = '1' then
                    v_popping := true;
                    o_async_rd_en <= '1';
                end if;
            end if;
        end if;
    end process p_handle;

end architecture behaviour;
