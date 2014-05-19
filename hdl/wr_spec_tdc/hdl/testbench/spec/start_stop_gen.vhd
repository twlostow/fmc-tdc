-- Created by : G. Penacoba
-- Creation Date: May 2011
-- Description: generates start and stop pulses for test-bench
-- Modified by:
-- Modification Date:
-- Modification consisted on:




library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

entity start_stop_gen is
    port(
        tstart_o                : out std_logic;
        tstop1_o                : out std_logic;
        tstop2_o                : out std_logic;
        tstop3_o                : out std_logic;
        tstop4_o                : out std_logic;
        tstop5_o                : out std_logic
    );
end start_stop_gen;

architecture behavioral of start_stop_gen is


signal tstart               : std_logic:='0';
signal tstop1               : std_logic:='0';
signal tstop2               : std_logic:='0';
signal tstop3               : std_logic:='0';
signal tstop4               : std_logic:='0';
signal tstop5               : std_logic:='0';

signal pulse_channel        : integer;
signal pulse_length         : time;

begin
	-- process reading the schedule of frame exchange from a text file
	------------------------------------------------------------------
	sequence: process
	file sequence_file			: text open read_mode is "data_vectors/pulses.txt";
	variable sequence_line		: line;
	variable interval_time		: time;
	variable coma				: string(1 to 1);
	variable pulse_ch   		: integer;
	variable pulse_lgth   		: time;
	
	begin
			readline	        (sequence_file, sequence_line);
			read		        (sequence_line, interval_time);
			read		        (sequence_line, coma);
			read		        (sequence_line, pulse_ch);
			read		        (sequence_line, coma);
			read		        (sequence_line, pulse_lgth);
			wait for interval_time;
            pulse_channel       <= pulse_ch;
            pulse_length        <= pulse_lgth;

			if endfile(sequence_file) then
				file_close(sequence_file);
                wait;
			end if;
	end process;
    
    start_extender: process
    begin
        wait until pulse_channel = 0;
        tstart      <= '1';
        wait for pulse_length;
        tstart      <= '0';
    end process;

    stop1_extender: process
    begin
        wait until pulse_channel = 1;
        tstop1      <= '1';
        wait for pulse_length;
        tstop1      <= '0';
    end process;
 
    stop2_extender: process
    begin
        wait until pulse_channel = 2;
        tstop2      <= '1';
        wait for pulse_length;
        tstop2      <= '0';
    end process;
 
    stop3_extender: process
    begin
        wait until pulse_channel = 3;
        tstop3      <= '1';
        wait for pulse_length;
        tstop3      <= '0';
    end process;
 
    stop4_extender: process
    begin
        wait until pulse_channel = 4;
        tstop4      <= '1';
        wait for pulse_length;
        tstop4      <= '0';
    end process;
 
    stop5_extender: process
    begin
        wait until pulse_channel = 5;
        tstop5      <= '1';
        wait for pulse_length;
        tstop5      <= '0';
    end process;

        tstart_o                <= tstart;
        tstop1_o                <= tstop1;
        tstop2_o                <= tstop2;
        tstop3_o                <= tstop3;
        tstop4_o                <= tstop4;
        tstop5_o                <= tstop5;

end behavioral;
