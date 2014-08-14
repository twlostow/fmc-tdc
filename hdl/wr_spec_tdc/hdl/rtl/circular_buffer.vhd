--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        circular_buffer                                         |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         circular_buffer.vhd                                                               |
--                                                                                                |
-- Description  Dual port RAM circular buffer for timestamp storage; contains the RAM block and   |
--              the WISHBONE slave interfaces:                                                    |
--               o The data_formatting unit is writing 128-bit long timestamps, using a WISHBONE  |
--                 classic interface. The unit implements a WISHBONE classic slave.               |
--                 As figure 1 indicates, from this side the memory is of size: 255 * 128.        |
--               o The GN4124/VME core is reading 32-bit words. Readings take place using         |
--                 pipelined WISHBONE interface. For the PCi-e interface, Direct Memory Access can|
--                 take place on this side. The unit implements the WISHBONE pipelined slave.     |
--                 As figure 1 indicates, from this side the memory is of size: 1024 * 32.        |
--                                                                                                |
--              Note also that in principle the data_formatting unit is only writing in the RAM   |
--              and the GN4124/VME core is only reading from it.                                  |
--                                                                                                |
--                                                                                                |
--                         RAM as seen from the                             RAM as seen from the  |
--                         data_formatting unit                                 GN4124/VME core   |
--     ____________________________________________________________            _______________    |
--  0 |                          128 bits                          |        0 |    32 bits    |   |
--    |____________________________________________________________|          |_______________|   |
--  1 |                          128 bits                          |        1 |    32 bits    |   |
--    |____________________________________________________________|          |_______________|   |
--  . |                          128 bits                          |        2 |    32 bits    |   |
--    |____________________________________________________________|  <==>    |_______________|   |
--  . |                          128 bits                          |        3 |    32 bits    |   |
--    |____________________________________________________________|          |_______________|   |
--    |                          128 bits                          |        4 |    32 bits    |   |
-- 255|____________________________________________________________|          |_______________|   |
--                                                                          . |    32 bits    |   |
--                                                                            |_______________|   |
--                                                                          . |    32 bits    |   |
--                                                                            |_______________|   |
--                                                                          . |    32 bits    |   |
--                                                                            |_______________|   |
--                                                                          . |    32 bits    |   |
--                                                                            |_______________|   |
--                                                                       1021 |    32 bits    |   |
--                                                                            |_______________|   |
--                                                                       1022 |    32 bits    |   |
--                                                                            |_______________|   |
--                                                                       1023 |    32 bits    |   |
--                                                                            |_______________|   |
--                               Figuure 1: RAM configuration                                     |
--                                                                                                |
--                                                                                                |
-- Authors      Gonzalo Penacoba  (Gonzalo.Penacoba@cern.ch)                                      |
--              Evangelia Gousiou (Evangelia.Gousiou@cern.ch)                                     |
-- Date         04/2012                                                                           |
-- Version      v0.11                                                                             |
-- Depends on                                                                                     |
--                                                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     10/2011  v0.1  GP  First version                                                           |
--     04/2012  v0.11 EG  Revamping; Comments added, signals renamed                              |
--                                                                                                |
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                              ------------------------------------                              |
-- This source file is free software; you can redistribute it and/or modify it under the terms of |
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     |
-- version 2.1 of the License, or (at your option) any later version.                             |
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       |
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.      |
-- See the GNU Lesser General Public License for more details.                                    |
-- You should have received a copy of the GNU Lesser General Public License along with this       |
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     |
---------------------------------------------------------------------------------------------------



--=================================================================================================
--                                       Libraries & Packages
--=================================================================================================

-- Standard library
library IEEE;
use IEEE.std_logic_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific library
library work;
use work.tdc_core_pkg.all;   -- definitions of types, constants, entities


--=================================================================================================
--                            Entity declaration for circular_buffer
--=================================================================================================

entity circular_buffer is
  port
  -- INPUTS
     -- Signal from the clk_rst_manager
    (clk_i                : in std_logic;                      -- 125 MHz clock; same for both ports

     -- Signals from the data_formatting unit (WISHBONE classic): timestamps writing
     tstamp_wr_rst_i   : in std_logic;                         -- timestamp writing WISHBONE reset
     tstamp_wr_stb_i   : in std_logic;                         -- timestamp writing WISHBONE strobe
     tstamp_wr_cyc_i   : in std_logic;                         -- timestamp writing WISHBONE cycle
     tstamp_wr_we_i    : in std_logic;                         -- timestamp writing WISHBONE write enable
     tstamp_wr_adr_i   : in std_logic_vector(7 downto 0);      -- adr 8 bits long 2^8 = 255
     tstamp_wr_dat_i   : in std_logic_vector(127 downto 0);    -- timestamp 128 bits long

     -- Signals from the GN4124/VME core unit (WISHBONE pipelined): timestamps reading
     tdc_mem_wb_rst_i    : in std_logic;                       -- timestamp reading WISHBONE reset
     tdc_mem_wb_stb_i    : in std_logic;                       -- timestamp reading WISHBONE strobe
     tdc_mem_wb_cyc_i    : in std_logic;                       -- timestamp reading WISHBONE cycle
     tdc_mem_wb_we_i     : in std_logic;                       -- timestamp reading WISHBONE write enable; not used
     tdc_mem_wb_adr_i    : in std_logic_vector(31 downto 0);   -- adr 10 bits long 2^10 = 1024
     tdc_mem_wb_dat_i    : in std_logic_vector(31 downto 0);   -- not used

  -- OUTPUTS
     -- Signals to the data_formatting unit (WISHBONE classic): timestamps writing
     tstamp_wr_ack_p_o : out std_logic;                        -- timestamp writing WISHBONE classic acknowledge
     tstamp_wr_dat_o   : out std_logic_vector(127 downto 0);   -- not used

     -- Signals to the GN4124/VME core unit (WISHBONE pipelined): timestamps reading
     tdc_mem_wb_ack_o     : out std_logic;                     -- timestamp reading WISHBONE pipelined acknowledge
     tdc_mem_wb_dat_o     : out std_logic_vector(31 downto 0); -- 32 bit words
     tdc_mem_wb_stall_o   : out std_logic);                    -- timestamp reading WISHBONE pipelined stall

end circular_buffer;

--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of circular_buffer is

  type t_wb_wr is (IDLE, MEM_ACCESS, MEM_ACCESS_AND_ACKNOWLEDGE, ACKNOWLEDGE);
  signal tstamp_rd_wb_st, nxt_tstamp_rd_wb_st : t_wb_wr;
  signal tstamp_wr_ack_p                      : std_logic;
  signal tstamp_rd_we, tstamp_wr_we           : std_logic_vector(0 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--                            TIMESTAMP WRITINGS WISHBONE CLASSIC ACK                            --
---------------------------------------------------------------------------------------------------
  -- WISHBONE classic interface compatible slave
  classic_interface: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if tstamp_wr_rst_i ='1' then
        tstamp_wr_ack_p <= '0';

      elsif tstamp_wr_stb_i = '1' and tstamp_wr_cyc_i = '1' and tstamp_wr_ack_p = '0' then
        tstamp_wr_ack_p <= '1';                    -- a new 1 clk-wide ack is given for each stb
      else
        tstamp_wr_ack_p <= '0';
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  tstamp_wr_ack_p_o     <= tstamp_wr_ack_p;


---------------------------------------------------------------------------------------------------
--                            TIMESTAMP READINGS WISHBONE PIPELINE ACK                           --
---------------------------------------------------------------------------------------------------
-- FSM for the generation of the pipelined WISHBONE ACK signal.
-- Note that the first output from the memory comes 2 clk cycles after the address setting.

-- CLK : --|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__
-- STB : _____|-----------------------------------|_________________
-- CYC : _____|-----------------------------------|_________________
-- ADR :      <ADR0><ADR1><ADR2><ADR3><ADR4><ADR5>
-- ACK : _________________|-----------------------------------|_____
-- DATO:                  <DAT0><DAT1><DAT2><DAT3><DAT4><DAT5>

  WB_pipe_ack_fsm_seq: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if tdc_mem_wb_rst_i ='1' then
        tstamp_rd_wb_st <= IDLE;
      else
        tstamp_rd_wb_st <= nxt_tstamp_rd_wb_st;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
  WB_pipe_ack_fsm_comb: process (tstamp_rd_wb_st, tdc_mem_wb_stb_i, tdc_mem_wb_cyc_i)
  begin
    case tstamp_rd_wb_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when IDLE =>
                -----------------------------------------------
                   tdc_mem_wb_ack_o    <= '0';
                -----------------------------------------------

                   if tdc_mem_wb_stb_i = '1' and tdc_mem_wb_cyc_i = '1' then
                     nxt_tstamp_rd_wb_st <= MEM_ACCESS;
                   else
                     nxt_tstamp_rd_wb_st <= IDLE;
                   end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when MEM_ACCESS =>

                -----------------------------------------------
                   tdc_mem_wb_ack_o    <= '0';
                -----------------------------------------------

                   if tdc_mem_wb_stb_i = '1' and tdc_mem_wb_cyc_i = '1' then
                     nxt_tstamp_rd_wb_st <= MEM_ACCESS_AND_ACKNOWLEDGE;
                   else
                     nxt_tstamp_rd_wb_st <= ACKNOWLEDGE;
                   end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when MEM_ACCESS_AND_ACKNOWLEDGE =>
                -----------------------------------------------
                   tdc_mem_wb_ack_o    <= '1';
                -----------------------------------------------

                   if tdc_mem_wb_stb_i = '1' and tdc_mem_wb_cyc_i = '1' then
                     nxt_tstamp_rd_wb_st <= MEM_ACCESS_AND_ACKNOWLEDGE;
                   else
                     nxt_tstamp_rd_wb_st <= ACKNOWLEDGE;
                   end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --            
      when ACKNOWLEDGE =>
                -----------------------------------------------
                   tdc_mem_wb_ack_o    <= '1';
                -----------------------------------------------

                   if tdc_mem_wb_stb_i = '1' and tdc_mem_wb_cyc_i = '1' then
                     nxt_tstamp_rd_wb_st <= MEM_ACCESS;
                   else
                     nxt_tstamp_rd_wb_st <= IDLE;
                   end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when others =>
                -----------------------------------------------
                   tdc_mem_wb_ack_o    <= '0';
                -----------------------------------------------

                   nxt_tstamp_rd_wb_st   <= IDLE;
    end case;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  tdc_mem_wb_stall_o <= '0';


---------------------------------------------------------------------------------------------------
--                                      DUAL PORT BLOCK RAM                                      --
---------------------------------------------------------------------------------------------------
  memory_block: blk_mem_circ_buff_v6_4
  port map(
    -- Port A: attached to the data_formatting unit
    clka   => clk_i,
    addra  => tstamp_wr_adr_i(7 downto 0), -- 2^8 = 256 addresses
    dina   => tstamp_wr_dat_i,             -- 128-bit long timestamps
    ena    => tstamp_wr_cyc_i,
    wea    => tstamp_wr_we,
    douta  => tstamp_wr_dat_o,             -- not used

    -- Port B: attached to the GN4124/VME_core unit
    clkb   => clk_i,
    addrb  => tdc_mem_wb_adr_i(9 downto 0),-- 2^10 = 1024 addresses
    dinb   => tdc_mem_wb_dat_i,            -- not used
    enb    => tdc_mem_wb_cyc_i,
    web    => tstamp_rd_we,                -- not used
   --------------------------------------------------
    doutb  => tdc_mem_wb_dat_o);           -- 32-bit long words
   --------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
    tstamp_wr_we(0) <= tstamp_wr_we_i;
    tstamp_rd_we(0) <= tdc_mem_wb_we_i;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
