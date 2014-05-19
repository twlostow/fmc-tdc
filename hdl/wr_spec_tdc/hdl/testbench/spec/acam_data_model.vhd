-- Created by : G. Penacoba
-- Creation Date: June 2011
-- Description: reproduced roughly the functionality of the acam:
--              handles the FIFO and the data communication handshake
-- Modified by:
-- Modification Date:
-- Modification consisted on:




library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity acam_data_model is
    port(
        start01_i               : in std_logic_vector(16 downto 0);
        timestamp_for_fifo1     : in std_logic_vector(27 downto 0);
        timestamp_for_fifo2     : in std_logic_vector(27 downto 0);

        address_i               : in std_logic_vector(3 downto 0);
        cs_n_i                  : in std_logic;
        oe_n_i                  : in std_logic;
        rd_n_i                  : in std_logic;
        wr_n_i                  : in std_logic;
       
        data_bus_o              : out std_logic_vector(27 downto 0);
        ef1_o                   : out std_logic;
        ef2_o                   : out std_logic;
        lf1_o                   : out std_logic;
        lf2_o                   : out std_logic
    );
end acam_data_model;

architecture behavioral of acam_data_model is

    component acam_fifo_model
    generic(
        size                : integer;
        full_threshold      : integer;
        empty_threshold     : integer
    );
    port(
        data_input          : in std_logic_vector(27 downto 0);
        rd_fifo             : in std_logic;
        
        data_output         : out std_logic_vector(27 downto 0);
        empty               : out std_logic;
        full                : out std_logic
    );
    end component;

constant ts_ad                  : time:= 2000 ps;       -- minimum address setup time
constant th_ad                  : time:= 0 ps;          -- minimum address hold time
constant tpw_rl                 : time:= 6000 ps;       -- minimum read low time
constant tpw_rh                 : time:= 6000 ps;       -- minimum read high time
constant tpw_wl                 : time:= 6000 ps;       -- minimum write low time
constant tpw_wh                 : time:= 6000 ps;       -- minimum write high time
constant tv_dr                  : time:= 11800 ps;      -- maximum read data valid time
constant th_dr                  : time:= 4000 ps;       -- minimum read data hold time
constant ts_dw                  : time:= 5000 ps;       -- minimum write data setup time
constant th_dw                  : time:= 4000 ps;       -- minimum write data hold time
constant ts_csn                 : time:= 0 ps;          -- minimum chip select setup time
constant th_csn                 : time:= 0 ps;          -- minimum chip select hold time
constant ts_ef                  : time:= 11800 ps;      -- maximum empty flag set time

signal address                  : std_logic_vector(3 downto 0);
signal cs_n                     : std_logic;
signal oe_n                     : std_logic;
signal rd_n                     : std_logic;
signal wr_n                     : std_logic;
       
signal data_bus                 : std_logic_vector(27 downto 0):= (others =>'Z');
signal ef1                      : std_logic;
signal ef2                      : std_logic;
signal lf1                      : std_logic;
signal lf2                      : std_logic;

signal address_change_time      : time:= 0 ps;
signal data_change_time         : time:= 0 ps;
signal cs_falling_time          : time:= 0 ps;
signal cs_rising_time           : time:= 0 ps;
signal rd_falling_time          : time:= 0 ps;
signal rd_rising_time           : time:= 0 ps;
signal wr_falling_time          : time:= 0 ps;
signal wr_rising_time           : time:= 0 ps;

signal start01                  : std_logic_vector(16 downto 0);
signal data_for_bus             : std_logic_vector(27 downto 0);
signal data_from_fifo1          : std_logic_vector(27 downto 0);
signal data_from_fifo2          : std_logic_vector(27 downto 0);
signal rd_fifo1                 : std_logic;
signal rd_fifo2                 : std_logic;

begin

    read: process
    begin
        wait until rd_n ='0';
        if cs_n ='0' then
            wait for tv_dr;
            data_bus        <= data_for_bus;
        end if;

        wait until rd_n ='1';
        if cs_n ='0' then
            wait for th_dr;
            data_bus        <= (others =>'Z');
        end if;
    end process;
    
    data_mux: process(address, data_from_fifo1, data_from_fifo2, start01, rd_n, cs_n)
    begin
    case address is
        when x"8" =>
            data_for_bus        <= data_from_fifo1;

            if rd_n ='0' and cs_n ='0' then
                rd_fifo1            <= '1';
                rd_fifo2            <= '0';
            else
                rd_fifo1            <= '0';
                rd_fifo2            <= '0';
            end if;
        
        when x"9" =>
            data_for_bus        <= data_from_fifo2;

            if rd_n ='0' and cs_n ='0' then
                rd_fifo1            <= '0';
                rd_fifo2            <= '1';
            else
                rd_fifo1            <= '0';
                rd_fifo2            <= '0';
            end if;
        
        when x"A" =>
            data_for_bus        <= "00000000000" & start01;

            rd_fifo1            <= '0';
            rd_fifo2            <= '0';

        when others =>
            data_for_bus        <= (others => 'Z');

            rd_fifo1            <= '0';
            rd_fifo2            <= '0';
        end case;
    end process;

    interface_fifo1: acam_fifo_model
    generic map(
        size                => 256,
        full_threshold      => 10,
        empty_threshold     => 1
    )
    port map(
        data_input          => timestamp_for_fifo1,
        rd_fifo             => rd_fifo1,
        
        data_output         => data_from_fifo1,
        empty               => ef1,
        full                => lf1
    );

    interface_fifo2: acam_fifo_model
    generic map(
        size                => 256,
        full_threshold      => 10,
        empty_threshold     => 1
    )
    port map(
        data_input          => timestamp_for_fifo2,
        rd_fifo             => rd_fifo2,
        
        data_output         => data_from_fifo2,
        empty               => ef2,
        full                => lf2
    );

    start01                 <= start01_i;
    address                 <= address_i;
    cs_n                    <= cs_n_i;
    oe_n                    <= oe_n_i;
    rd_n                    <= rd_n_i;
    wr_n                    <= wr_n_i;
       
    data_bus_o              <= data_bus;
    ef1_o                   <= ef1;
    ef2_o                   <= ef2;
    lf1_o                   <= lf1;
    lf2_o                   <= lf2;

    address_timing: process(address)
    begin
        address_change_time         <= now;
    end process;
    
    data_timing: process(address)
    begin
        data_change_time            <= now;
    end process;
    
    read_timing: process(rd_n)
    begin
        if falling_edge(rd_n) then
            rd_falling_time         <= now;
        end if;
        if rising_edge(rd_n) then
            rd_rising_time          <= now;
        end if;
    end process;
    
    write_timing: process(wr_n)
    begin
        if falling_edge(wr_n) then
            wr_falling_time         <= now;
        end if;
        if rising_edge(wr_n) then
            wr_rising_time          <= now;
        end if;
    end process;
    
    chip_select_timing: process(cs_n)
    begin
        if falling_edge(cs_n) then
            cs_falling_time         <= now;
        end if;
        if rising_edge(cs_n) then
            cs_rising_time          <= now;
        end if;
    end process;
    
    reporting_read_times: process(rd_falling_time, rd_rising_time)
    begin
        if rd_rising_time - rd_falling_time < tpw_rl 
        and rd_rising_time - rd_falling_time > 0 ps
        and now /= 0 ps then
            report LF & " #### Timing error in read signal when reading: minimum low time not respected" & LF
            severity warning;
        end if;
        
        if rd_falling_time - rd_rising_time < tpw_rh 
        and rd_falling_time - rd_rising_time > 0 ps
        and now /= 0 ps then
            report LF & " #### Timing error in read signal when reading: minimum high time not respected" & LF
            severity warning;
        end if;
    end process;
        
    reporting_write_times: process(wr_falling_time, wr_rising_time)
    begin
        if wr_rising_time - wr_falling_time < tpw_wl 
        and wr_rising_time - wr_falling_time > 0 ps
        and now /= 0 ps then
            report LF & " #### Timing error in read signal when writing: minimum low time not respected" & LF
            severity warning;
        end if;
        
        if wr_falling_time - wr_rising_time < tpw_wh 
        and wr_falling_time - wr_rising_time > 0 ps
        and now /= 0 ps then
            report " #### Timing error in read signal when writing: minimum high time not respected" & LF
            severity warning;
        end if;
    end process;
        
    reporting_setup_rd: process(rd_falling_time)
    begin
        if rd_falling_time - address_change_time < ts_ad and now /= 0 ps then
            report LF & " #### Timing error in address bus when reading: minimum setup time not respected" & LF
            severity warning;
        end if;
        if rd_falling_time - cs_falling_time < ts_csn and now /= 0 ps then
            report LF & " #### Timing error in chip select signal when reading: minimum setup time not respected" & LF
            severity warning;
        end if;
    end process;
    
    reporting_setup_wr: process(wr_falling_time)
    begin
        if wr_falling_time - address_change_time < ts_ad and now /= 0 ps then
            report LF & " #### Timing error in address bus when writing: minimum setup time not respected" & LF
            severity warning;
        end if;
        if wr_falling_time - cs_falling_time < ts_csn then
            report LF & " #### Timing error in chip select signal when writing: minimum setup time not respected" & LF
            severity warning;
        end if;
    end process;
    
    reporting_hold_ad: process(address_change_time)
    begin
        if address_change_time - rd_rising_time < th_ad and now /= 0 ps then
            report LF & " #### Timing error in address bus when reading: minimum hold time not respected" & LF
            severity warning;
        end if;
        if address_change_time - wr_rising_time < th_ad and now /= 0 ps then
            report LF & " #### Timing error in address bus when writing: minimum hold time not respected" & LF
            severity warning;
        end if;
    end process;
    
    reporting_hold_cs: process(cs_rising_time)
    begin
        if cs_rising_time - rd_rising_time < th_csn and now /= 0 ps then
            report LF & " #### Timing error in chip select signal when reading: minimum hold time not respected" & LF
            severity warning;
        end if;
        if cs_rising_time - wr_rising_time < th_csn and now /= 0 ps then
            report LF & " #### Timing error in chip select signal when writing: minimum hold time not respected" & LF
            severity warning;
        end if;
    end process;
    
    reporting_data_setup_wr: process(wr_rising_time)
    begin
        if  wr_rising_time - data_change_time < ts_dw and now /= 0 ps then
            report LF & " #### Timing error in data bus when writing: minimum setup time not respected" & LF
            severity warning;
        end if;
    end process;
    
    reporting_data_hold_wr: process(data_change_time)
    begin
        if  data_change_time - wr_rising_time < th_dw and now /= 0 ps then
            report LF & " #### Timing error in data bus when writing: minimum hold time not respected" & LF
            severity warning;
        end if;
    end process;
    
end behavioral;
