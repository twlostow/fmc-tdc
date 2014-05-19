-- Created by : G. Penacoba
-- Creation Date: May 2011
-- Description: reproduced roughly the functionality of the acam:
--              measures the time between input pulses.
-- Modified by:
-- Modification Date:
-- Modification consisted on:




library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity acam_timing_model is
    generic(
        refclk_period           : time:= 32 ns;
        start_retrig_period     : time:= 3200 ns
    );
    port(
        tstart_i                : in std_logic;
        tstop1_i                : in std_logic;
        tstop2_i                : in std_logic;
        tstop3_i                : in std_logic;
        tstop4_i                : in std_logic;
        tstop5_i                : in std_logic;
        startdis_i              : in std_logic;
        stopdis_i               : in std_logic;
        
        err_flag_o              : out std_logic;
        int_flag_o              : out std_logic;
        start01_o               : out std_logic_vector(16 downto 0);
        timestamp_for_fifo1     : out std_logic_vector(27 downto 0);
        timestamp_for_fifo2     : out std_logic_vector(27 downto 0)
    );
end acam_timing_model;

architecture behavioral of acam_timing_model is

constant resolution       : time:= 81 ps;


signal tstart           : std_logic;
signal tstop1           : std_logic;
signal tstop2           : std_logic;
signal tstop3           : std_logic;
signal tstop4           : std_logic;
signal tstop5           : std_logic;

signal startdis         : std_logic;
signal stopdis          : std_logic;
signal intflag          : std_logic;
signal start01_reg      : std_logic_vector(16 downto 0);

signal start01          : time:= 0 ps;

signal start_trig       : time:= 0 ps;
signal stop1_trig       : time:= 0 ps;
signal stop2_trig       : time:= 0 ps;
signal stop3_trig       : time:= 0 ps;
signal stop4_trig       : time:= 0 ps;
signal stop5_trig       : time:= 0 ps;

signal stop1            : time:= 0 ps;
signal stop2            : time:= 0 ps;
signal stop3            : time:= 0 ps;
signal stop4            : time:= 0 ps;
signal stop5            : time:= 0 ps;

signal start_nb1        : integer:=0;
signal start_nb2        : integer:=0;
signal start_nb3        : integer:=0;
signal start_nb4        : integer:=0;
signal start_nb5        : integer:=0;

signal start_retrig_nb  : integer:=0;
signal start_retrig_p   : std_logic;

begin
    
    listening: process (tstart, tstop1, tstop2, tstop3, tstop4, tstop5)
    begin
        if rising_edge(tstart) then
            if startdis ='0' then
                start_trig          <= now;
            end if;
        end if;
        if rising_edge(tstop1) then
            if stopdis ='0' then
                stop1_trig          <= now;
            end if;
        end if;
        if rising_edge(tstop2) then
            if stopdis ='0' then
                stop2_trig          <= now;
            end if;
        end if;
        if rising_edge(tstop3) then
            if stopdis ='0' then
                stop3_trig          <= now;
            end if;
        end if;
        if rising_edge(tstop4) then
            if stopdis ='0' then
                stop4_trig          <= now;
            end if;
        end if;
        if rising_edge(tstop5) then
            if stopdis ='0' then
                stop5_trig          <= now;
            end if;
        end if;
    end process;
    
    measuring1: process(stop1_trig)
    begin
        if start_retrig_nb > 1 then
            stop1           <= (stop1_trig-start_trig-start01)-((start_retrig_nb-1)*start_retrig_period);
        elsif start_retrig_nb = 1 then
            stop1           <= (stop1_trig-start_trig-start01);
        else
            stop1           <= (stop1_trig-start_trig);
        end if;        
        start_nb1       <= start_retrig_nb mod 256;
    end process;

    measuring2: process(stop2_trig)
    begin
        if start_retrig_nb > 1 then
            stop2           <= (stop2_trig-start_trig-start01)-((start_retrig_nb-1)*start_retrig_period);
        elsif start_retrig_nb = 1 then
            stop2           <= (stop2_trig-start_trig-start01);
        else
            stop2           <= (stop2_trig-start_trig);
        end if;        
        start_nb2       <= start_retrig_nb mod 256;
    end process;

    measuring3: process(stop3_trig)
    begin
        if start_retrig_nb > 1 then
            stop3           <= (stop3_trig-start_trig-start01)-((start_retrig_nb-1)*start_retrig_period);
        elsif start_retrig_nb = 1 then
            stop3           <= (stop3_trig-start_trig-start01);
        else
            stop3           <= (stop3_trig-start_trig);
        end if;        
        start_nb3       <= start_retrig_nb mod 256;
    end process;

    measuring4: process(stop4_trig)
    begin
        if start_retrig_nb > 1 then
            stop4           <= (stop4_trig-start_trig-start01)-((start_retrig_nb-1)*start_retrig_period);
        elsif start_retrig_nb = 1 then
            stop4           <= (stop4_trig-start_trig-start01);
        else
            stop4           <= (stop4_trig-start_trig);
        end if;        
        start_nb4       <= start_retrig_nb mod 256;
    end process;

    measuring5: process(stop5_trig)
    begin
        if start_retrig_nb > 1 then
            stop5           <= (stop5_trig-start_trig-start01)-((start_retrig_nb-1)*start_retrig_period);
        elsif start_retrig_nb = 1 then
            stop5           <= (stop5_trig-start_trig-start01);
        else
            stop5           <= (stop5_trig-start_trig);
        end if;        
        start_nb5       <= start_retrig_nb mod 256;
    end process;

    measuring_start01: process(start_retrig_p)
    begin
        if rising_edge(start_retrig_p) then
            if start_retrig_nb = 0 then
                start01            <= now - start_trig;
            end if;
        end if;
    end process;

    writing_fifo1: process (tstop1, tstop2, tstop3, tstop4)
    begin
        if falling_edge(tstop1) then
            timestamp_for_fifo1(27 downto 26)       <= "00";
            timestamp_for_fifo1(25 downto 18)       <= std_logic_vector(to_unsigned(start_nb1,8));
            timestamp_for_fifo1(17)                 <= '1';
            timestamp_for_fifo1(16 downto 0)        <= std_logic_vector(to_unsigned(stop1/resolution,17));
            start01_reg                             <= std_logic_vector(to_unsigned(start01/resolution,17));
            report " Timestamp for interface FIFO 1:" & LF &
                    "===============================" & LF &
                    "Channel 1" & LF &
                    "Start number: " & integer'image(start_nb1) & LF &
                    "Time Interval: " & integer'image(stop1/resolution) & LF &
                    "Start01: " & integer'image(start01/resolution) & LF;
        end if;

        if falling_edge(tstop2) then
            timestamp_for_fifo1(27 downto 26)       <= "01";
            timestamp_for_fifo1(25 downto 18)       <= std_logic_vector(to_unsigned(start_nb2,8));
            timestamp_for_fifo1(17)                 <= '1';
            timestamp_for_fifo1(16 downto 0)        <= std_logic_vector(to_unsigned(stop2/resolution,17));
            start01_reg                             <= std_logic_vector(to_unsigned(start01/resolution,17));
            report " Timestamp for interface FIFO 1:" & LF &
                    "===============================" & LF &
                    "Channel 2" & LF &
                    "Start number: " & integer'image(start_nb2) & LF &
                    "Time Interval: " & integer'image(stop2/resolution) & LF &
                    "Start01: " & integer'image(start01/resolution) & LF;
        end if;

        if falling_edge(tstop3) then
            timestamp_for_fifo1(27 downto 26)       <= "10";
            timestamp_for_fifo1(25 downto 18)       <= std_logic_vector(to_unsigned(start_nb3,8));
            timestamp_for_fifo1(17)                 <= '1';
            timestamp_for_fifo1(16 downto 0)        <= std_logic_vector(to_unsigned(stop3/resolution,17));
            start01_reg                             <= std_logic_vector(to_unsigned(start01/resolution,17));
            report " Timestamp for interface FIFO 1:" & LF &
                    "===============================" & LF &
                    "Channel 3" & LF &
                    "Start number: " & integer'image(start_nb3) & LF &
                    "Time Interval: " & integer'image(stop3/resolution) & LF &
                    "Start01: " & integer'image(start01/resolution) & LF;
        end if;

        if falling_edge(tstop4) then
            timestamp_for_fifo1(27 downto 26)       <= "11";
            timestamp_for_fifo1(25 downto 18)       <= std_logic_vector(to_unsigned(start_nb4,8));
            timestamp_for_fifo1(17)                 <= '1';
            timestamp_for_fifo1(16 downto 0)        <= std_logic_vector(to_unsigned(stop4/resolution,17));
            start01_reg                             <= std_logic_vector(to_unsigned(start01/resolution,17));
            report " Timestamp for interface FIFO 1:" & LF &
                    "===============================" & LF &
                    "Channel 4" & LF &
                    "Start number: " & integer'image(start_nb4) & LF &
                    "Time Interval: " & integer'image(stop4/resolution) & LF &
                    "Start01: " & integer'image(start01/resolution) & LF;
        end if;
    end process;

    writing_fifo2: process (tstop5)
    begin
        if falling_edge(tstop5) then
            timestamp_for_fifo2(27 downto 26)       <= "00";
            timestamp_for_fifo2(25 downto 18)       <= std_logic_vector(to_unsigned(start_nb5,8));
            timestamp_for_fifo2(17)                 <= '1';
            timestamp_for_fifo2(16 downto 0)        <= std_logic_vector(to_unsigned(stop5/resolution,17));
            start01_reg                             <= std_logic_vector(to_unsigned(start01/resolution,17));
            report " Timestamp for interface FIFO 2:" & LF &
                    "===============================" & LF &
                    "Channel 5" & LF &
                    "Start number: " & integer'image(start_nb5) & LF &
                    "Time Interval: " & integer'image(stop5/resolution) & LF &
                    "Start01: " & integer'image(start01/resolution) & LF;
        end if;
    end process;

    start_retrigger_pulses: process
    begin
        start_retrig_p      <= '0' after 333 ps;
        wait for start_retrig_period/4;
        start_retrig_p      <= '1' after 333 ps;
        wait for start_retrig_period/4;
        start_retrig_p      <= '0' after 333 ps;
        wait for start_retrig_period/2;
    end process;
    
    start_nb_counter: process(tstart, start_retrig_p)
    begin
        if rising_edge(tstart) then
            start_retrig_nb     <= 0;
        elsif rising_edge(start_retrig_p) then
            start_retrig_nb     <= start_retrig_nb + 1;
        end if;
    end process;
    
    interrupt_flag: process(start_retrig_nb)
    begin
        if (start_retrig_nb mod 256) > 127 then
            intflag             <= '1';
        else
            intflag             <= '0';
        end if;
    end process;

    tstart                      <= tstart_i;
    tstop1                      <= tstop1_i;
    tstop2                      <= tstop2_i;
    tstop3                      <= tstop3_i;
    tstop4                      <= tstop4_i;
    tstop5                      <= tstop5_i;
    
    startdis                    <= startdis_i;
    stopdis                     <= stopdis_i;
    
    int_flag_o                  <= intflag;
    
    start01_o                   <= start01_reg;

end behavioral;

        
