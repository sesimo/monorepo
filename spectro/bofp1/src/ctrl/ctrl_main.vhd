
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ctrl_common.all;

entity ctrl_main is
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        
        i_sub_data: in std_logic_vector(3 downto 0);
        i_sub_rdy: in std_logic;

        o_ccd_sample: out std_logic
    );
end entity ctrl_main;

architecture behaviour of ctrl_main is
    signal r_cdc_data: std_logic_vector(i_sub_data'range);
    signal r_cdc_rdy: std_logic;

    signal r_sub_data: std_logic_vector(i_sub_data'range);
    signal r_sub_rdy: std_logic;

    signal r_sub_count: integer;

    signal o_test: std_logic;
begin

    p_count: process(i_clk, i_rst_n) is
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_sub_count <= 0;
            elsif r_sub_rdy = '1' then
                r_sub_count <= (r_sub_count + 1 ) mod 4;
            end if;
        end if;
    end process p_count;

    -- Cross clock domain with the sub data and the sub ready signal
    p_cdc: process(i_clk, i_rst_n) is
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_sub_rdy <= '0';
            else
                r_sub_rdy <= '1' when (r_cdc_rdy = '1' and r_sub_rdy = '0')
                             else '0';
                r_sub_data <= r_cdc_data;

                r_cdc_rdy <= i_sub_rdy;
                r_cdc_data <= i_sub_data;
            end if;
        end if;
    end process p_cdc;

    p_handle: process(i_clk, i_rst_n) is
        variable v_count_last: integer;
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                v_count_last := 0;
                o_ccd_sample <= '0';
            else
                o_ccd_sample <= '0';

                if r_sub_count =  1 and r_sub_count /= v_count_last then
                    -- In the second 4-bit sequence. Register has been received
                    -- and we can issue the correct command base on it.
                    case parse_reg(r_sub_data) is
                        when REG_SAMPLE =>
                            o_ccd_sample <= '1';

                        when others => o_test <= 'Z';

                    end case;
                end if;

                v_count_last := r_sub_count;
            end if;
        end if;
    end process p_handle;

end architecture behaviour;
