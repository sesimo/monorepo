library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- brief Double flip flop for input synchronization
entity dff is 
    port (
        i_clk: in std_logic;
        i_rst_n: in std_logic;
        i_sig: in std_logic;

        o_sig: out std_logic
    );
end entity dff;

architecture rtl of dff is
    signal r_unsafe: std_logic;
begin

    p_dff: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                o_sig <= 'X';
                r_unsafe <= 'X';
            else
                o_sig <= r_unsafe;
                r_unsafe <= i_sig;
            end if;
        end if;
    end process p_dff;

end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic (
        G_WIDTH: integer
    );

    port (
        i_clk: in std_logic;
        i_start: in std_logic;
        i_cyc_cnt: in std_logic_vector(G_WIDTH-1 downto 0);
        i_rst_n: in std_logic;
        o_int: out std_logic
    );
end entity counter;

architecture rtl of counter is
    signal r_count: integer;
begin

    p_count: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst_n = '0' then
                r_count <= 0;
                o_int <= '0';
            else
                r_count <= r_count + 1;
                o_int <= '0';

                if r_count = 0 then
                    o_int <= '1';

                    -- Only restart when i_start is high
                    if i_start = '0' then
                        r_count <= 0;
                    end if;
                elsif r_count >= unsigned(i_cyc_cnt) - 1 then
                    r_count <= 0;
                end if;
            end if;
        end if;
    end process p_count;

end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- brief Enable generator
entity enable is
    generic (
        G_WIDTH: integer
    );
    port (
        i_clk: in std_logic;
        i_clk_div: in std_logic_vector(G_WIDTH-1 downto 0);
        i_rst_n: in std_logic;
        o_enable: out std_logic
    );
end entity enable;

architecture rtl of enable is
begin
    u_counter: entity work.counter(rtl) generic map (
        G_WIDTH => G_WIDTH
    )
    port map(
        i_clk => i_clk,
        i_start => '1',
        i_cyc_cnt => i_clk_div,
        i_rst_n => i_rst_n,
        o_int => o_enable
    );
end architecture rtl;
