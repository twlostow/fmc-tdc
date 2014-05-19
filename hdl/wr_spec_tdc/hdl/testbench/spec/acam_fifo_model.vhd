-- Created by : G. Penacoba
-- Creation Date: June 2011
-- Description: reproduces roughly the functionality of the acam:
--              handles the FIFO and the data communication handshake
-- Modified by:
-- Modification Date:
-- Modification consisted on:




library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity acam_fifo_model is
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
end acam_fifo_model;

architecture behavioral of acam_fifo_model is

constant ts_ef              : time:= 11800 ps;      -- maximum empty flag set time

subtype index               is natural range size-1 downto 0;
subtype memory_cell         is std_logic_vector(27 downto 0);
type memory_block           is array (natural range size-1 downto 0) of memory_cell;

signal fifo                 : memory_block;
signal wr_pointer           : index:= 0;
signal rd_pointer           : index:= 0;
signal level                : index:= 0;

begin


    writing: process(data_input)
    begin
        if now /= 0 ps then
            fifo(wr_pointer)        <= data_input;
            if wr_pointer = size-1 then
                wr_pointer          <= 0;
            else
                wr_pointer          <= wr_pointer + 1;
            end if;
        end if;
    end process;
    
    reading: process(rd_fifo)
    begin
        if rising_edge(rd_fifo) then
            data_output             <= fifo(rd_pointer);

            if rd_pointer = size-1 then
                rd_pointer          <= 0 after ts_ef;
            else
                rd_pointer          <= rd_pointer + 1 after ts_ef;
            end if;

        end if;
        
--        if falling_edge(rd_fifo) then
--            if rd_pointer = size-1 then
--                rd_pointer          <= 0;
--            else
--                rd_pointer          <= rd_pointer + 1;
--            end if;
--        end if;
    end process;
    
    flags: process(level)
    begin
        if level > full_threshold then
            full                <= '1';
        else
            full                <= '0';
        end if;
        if level < empty_threshold then
            empty               <= '1';
        else
            empty               <= '0';
        end if;
    end process;

    filling_level: process(rd_pointer, wr_pointer)
    begin
        if wr_pointer >= rd_pointer then
            level               <= wr_pointer - rd_pointer;
        else
            level               <= wr_pointer + 256 - rd_pointer;
        end if;
        
    end process;
    
--    process(level)
--    begin
--        report  " filling level " & integer'image(level) & LF &
--                " rd_pointer " & integer'image(rd_pointer) & LF &
--                " wr_pointer " & integer'image(wr_pointer) & LF;
--    end process;
    
    corruption_reporting_reading: process(rd_pointer)
    begin
        if now /= 0 ps then
            if rd_pointer = wr_pointer then
                report LF & " #### Interface FIFO is empty: no further reading should be performed" & LF
                severity warning;
            end if;
        end if;
    end process;
                
    corruption_reporting_writing: process(wr_pointer)
    begin
        if now /= 0 ps then
            if rd_pointer = wr_pointer then
                report LF & " #### Interface FIFO is full: no further writing should be performed" & LF
                severity warning;
            end if;
        end if;
    end process;

end behavioral;










