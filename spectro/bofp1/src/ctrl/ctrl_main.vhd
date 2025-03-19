
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

        o_ccd_sample: out std_logic;
        o_rst: out std_logic;
        o_regmap: out t_regmap
    );
end entity ctrl_main;

architecture behaviour of ctrl_main is
    signal r_sub_data: std_logic_vector(i_sub_data'range);
    signal r_sub_rdy: std_logic;

    signal r_sub_count: integer range 0 to 3;
begin
    r_sub_rdy <= i_sub_rdy;
    r_sub_data <= i_sub_data;

    p_handle: process(i_clk) is
        variable v_reg: t_reg_vector;
        variable v_octet: std_logic_vector(7 downto 0);
    begin
        if rising_edge(i_clk) then
            o_ccd_sample <= '0';
            o_rst <= '0';

            if i_rst_n = '0' then
                r_sub_count <= 0;

                o_regmap <= c_regmap_default;
                v_octet := (others => 'Z');
            else
                if r_sub_rdy = '1' then
                    if r_sub_count /= 3 then
                        r_sub_count <= r_sub_count + 1;
                    else
                        r_sub_count <= 0;
                    end if;

                    v_octet := v_octet(3 downto 0) & r_sub_data;

                    if r_sub_count = 0 then
                        -- After the first 4-bit sequence. Register has been
                        -- received and we can issue the correct
                        -- command based on it.
                        v_reg := r_sub_data;

                        if is_write(v_reg) then
                            case parse_reg(v_reg) is
                                when REG_SAMPLE =>
                                    o_ccd_sample <= '1';

                                when others => null;

                            end case;
                        end if;
                    elsif r_sub_count = 3 and is_write(v_reg) then
                        -- After the last 4-bit sequence
                        case parse_reg(v_reg) is
                            when REG_CLKDIV =>
                                o_regmap.clkdiv <= v_octet;

                            when REG_SHDIV =>
                                o_regmap.shdiv <= v_octet;

                            when REG_RESET =>
                                o_rst <= '1';

                            when others => null;

                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process p_handle;

end architecture behaviour;
