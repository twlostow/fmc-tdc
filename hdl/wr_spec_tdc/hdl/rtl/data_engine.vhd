--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                          data_engine                                           |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         data_engine.vhd                                                                   |
--                                                                                                |
-- Description  The unit is managing:                                                             |
--               o the timestamps' acquisition from the ACAM,                                     |
--               o the writing of the ACAM configuration,                                         |
--               o the reading back of the ACAM configuration.                                    |
--                                                                                                |
--              The signals: activate_acq, deactivate_acq,                                        |
--                           acam_wr_config, acam_rst                                             |
--                           acam_rdbk_config, acam_rdbk_status, acam_rdbk_ififo1,                |
--                           acam_rdbk_ififo2, acam_rdbk_start01                                  |
--              coming from the reg_ctrl unit determine the actions of this unit.                 |
--                                                                                                |
--               o In acquisition mode (activate_acq = 1) the unit monitors permanently the empty |
--                 flags (ef1, ef2) of the ACAM iFIFOs, reads timestamps accordingly and then     |
--                 sends them to the data_formatting unit for them to endup in the circular_buffer|
--               o To configure the ACAM or read back its configuration registers, the unit should|
--                 be in inactive mode (deactivate_acq = 1).                                      |
--                                                                                                |
--              For all types of interactions with the ACAM chip, the unit acts as a WISHBONE     |
--              master fetching/ sending data from/to the ACAM interface.                         |
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
--     06/2011  v0.1  GP  First version                                                           |
--     04/2012  v0.11 EG  Revamping; Comments added, signals renamed                              |
--     14/2014  v1    EG  added state RD_START01                                                  |
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
--                            Entity declaration for data_engine
--=================================================================================================

entity data_engine is
  port
  -- INPUTS
     -- Signals from the clk_rst_manager
    (clk_i                : in std_logic;                     -- 125 MHz
     rst_i                : in std_logic;                     -- global reset

     -- Signals from the reg_ctrl unit: communication with GN4124/VME for registers configuration
     activate_acq_p_i     : in std_logic;                     -- activates tstamps aquisition 
     deactivate_acq_p_i   : in std_logic;                     -- for configuration readings/ writings
     acam_wr_config_p_i   : in std_logic;                     -- enables writing acam_config_i values to ACAM regs 0-7, 11, 12, 14 
     acam_rst_p_i         : in std_logic;                     -- enables writing c_RESET_WORD         to ACAM reg 4
     acam_rdbk_config_p_i : in std_logic;                     -- enables reading of ACAM regs 0-7, 11, 12, 14 
     acam_rdbk_status_p_i : in std_logic;                     -- enables reading of ACAM reg  12
     acam_rdbk_ififo1_p_i : in std_logic;                     -- enables reading of ACAM reg  8
     acam_rdbk_ififo2_p_i : in std_logic;                     -- enables reading of ACAM reg  9
     acam_rdbk_start01_p_i: in std_logic;                     -- enables reading of ACAM reg  10

     acam_config_i        : in config_vector;                 -- array keeping values for ACAM regs 0-7, 11, 12, 14
                                                              -- as received from the GN4124/VME interface

     -- Signals from the acam_databus_interface unit: empty FIFO flags
     acam_ef1_i           : in std_logic;                     -- empty fifo 1 (fully synched signal; ef1 after 2 DFFs)
     acam_ef1_meta_i      : in std_logic;                     -- empty fifo 1 (possibly metestable;  ef1 after 1 DFF)
     acam_ef2_i           : in std_logic;                     -- empty fifo 2 (fully synched signal; ef2 after 2 DFFs)
     acam_ef2_meta_i      : in std_logic;                     -- empty fifo 2 (possibly metestable;  ef2 after 1 DFF)

     -- Signals from the acam_databus_interface unit: communication with ACAM for configuration or tstamps retreival
     acam_ack_i           : in std_logic;                     -- WISHBONE ack
     acam_dat_i           : in std_logic_vector(31 downto 0); -- tstamps or rdbk regs
                                                              -- includes ef1 & ef2 & 0 & 0 & 28 bits ACAM data_bus_io

     start_from_fpga_i    : in  std_logic;
															  
  -- OUTPUTS
     state_active_p_o     : out std_logic;
  
     -- Signals to the acam_databus_interface unit: communication with ACAM for configuration or tstamps retreival
     acam_adr_o           : out std_logic_vector(7 downto 0); -- address of reg/ FIFO to write/ read
     acam_cyc_o           : out std_logic;                    -- WISHBONE cycle
     acam_stb_o           : out std_logic;                    -- WISHBONE strobe
     acam_dat_o           : out std_logic_vector(31 downto 0);-- values to write to ACAM regs
     acam_we_o            : out std_logic;                    -- WISHBONE write (enabled only for reg writings)

     -- Signals to the reg_ctrl unit: communication with GN4124/VME for registers configuration
     acam_config_rdbk_o   : out config_vector;                -- array keeping values read from ACAM regs 0-7, 11, 12, 14
     acam_ififo1_o        : out std_logic_vector(31 downto 0);-- keeps value read from ACAM reg 8
     acam_ififo2_o        : out std_logic_vector(31 downto 0);-- keeps value read from ACAM reg 9
     acam_start01_o       : out std_logic_vector(31 downto 0);-- keeps value read from ACAM reg 10

     -- Signals to the data_formatting unit: ACAM fine times
     acam_tstamp1_o       : out std_logic_vector(31 downto 0);-- includes ef1 & ef2 & 0 & 0 & 28 bits tstamp from FIFO1
     acam_tstamp2_o       : out std_logic_vector(31 downto 0);-- includes ef1 & ef2 & 0 & 0 & 28 bits tstamp from FIFO2
     acam_tstamp1_ok_p_o  : out std_logic;                    -- indication of a valid tstamp1
     acam_tstamp2_ok_p_o  : out std_logic);                   -- indication of a valid tstamp2

end data_engine;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================

architecture rtl of data_engine is

  type engine_state_ty is (ACTIVE, INACTIVE, GET_STAMP1, GET_STAMP2, WR_CONFIG, RDBK_CONFIG,
                           RD_STATUS, RD_IFIFO1, RD_IFIFO2, RD_START01, WR_RESET, WAIT_FOR_START01, WAIT_START_FROM_FPGA, WAIT_UTC);
  signal engine_st, nxt_engine_st    : engine_state_ty;

  signal acam_cyc, acam_stb, acam_we : std_logic;
  signal acam_adr                    : std_logic_vector(7 downto 0);
  signal config_adr_c                : unsigned(7 downto 0);
  signal acam_config_rdbk            : config_vector;
  signal reset_word                  : std_logic_vector(31 downto 0);
  signal acam_config_reg4            : std_logic_vector(31 downto 0);

  signal time_c_full_p, time_c_en    : std_logic;
  signal time_c_rst                  : std_logic;
  signal time_c                      : std_logic_vector(31 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                             FSM                                               --
---------------------------------------------------------------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- data_engine_fsm_seq FSM: the state machine is divided in three parts (a clocked process
-- to store the current state, a combinatorial process to manage state transitions and finally a
-- combinatorial process to manage the output signals), which are the three processes that follow.

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Synchronous process: storage of the current state of the FSM

  data_engine_fsm_seq: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then
        engine_st <= INACTIVE;
      else
        engine_st <= nxt_engine_st;
      end if;
    end if;
  end process;
    
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- Combinatorial process
  data_engine_fsm_comb: process (engine_st, activate_acq_p_i, deactivate_acq_p_i, acam_ef1_i, acam_adr,
                                 acam_ef2_i, acam_ef1_meta_i, acam_ef2_meta_i, acam_wr_config_p_i,
                                 acam_rdbk_config_p_i, acam_rdbk_status_p_i, acam_ack_i, acam_rst_p_i,
                                 acam_rdbk_ififo1_p_i, acam_rdbk_ififo2_p_i, acam_rdbk_start01_p_i)
  begin
    case engine_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      -- from the INACTIVE state modifications/readings of the ACAM configuration can be initiated;
      -- all interactions here refer to transfers between the ACAM and locally this core.
      -- All the interactions between the GN4124/VME interface and this core take place at the
      -- the reg_ctrl unit.  
      when INACTIVE =>
                  -----------------------------------------------
                        acam_cyc        <= '0';
                        acam_stb        <= '0';
                        acam_we         <= '0';
                        time_c_en       <= '0';
                        time_c_rst      <= '1';
                  -----------------------------------------------
            
                        if activate_acq_p_i = '1' then   -- activation of timestamps acquisition
                          nxt_engine_st   <= WAIT_START_FROM_FPGA;

                        elsif acam_wr_config_p_i = '1' then
                          nxt_engine_st   <= WR_CONFIG;  -- loading of ACAM config (local-> ACAM)

                        elsif acam_rdbk_config_p_i = '1' then
                          nxt_engine_st   <= RDBK_CONFIG;-- readback of ACAM config (ACAM->local acam_config_rdbk( downto ))

                        elsif acam_rdbk_status_p_i = '1' then
                          nxt_engine_st   <= RD_STATUS;  -- reading of ACAM status reg (ACAM->local acam_config_rdbk(9))

                        elsif acam_rdbk_ififo1_p_i = '1' then
                          nxt_engine_st   <= RD_IFIFO1;  -- reading of ACAM last iFIFO1 timestamp (ACAM->local acam_ififo1)
                                                         -- this option is available for debugging purposes only

                        elsif acam_rdbk_ififo2_p_i = '1' then
                          nxt_engine_st   <= RD_IFIFO2;  -- reading of ACAM last iFIFO2 timestamp (ACAM->local acam_ififo2)
                                                         -- this option is available for debugging purposes only

                        elsif acam_rdbk_start01_p_i = '1' then
                          nxt_engine_st   <= RD_START01; -- reading of ACAM Start01 reg (ACAM->local acam_start01)
                                                         -- this option is available for debugging purposes only

                        elsif acam_rst_p_i = '1' then
                          nxt_engine_st   <= WR_RESET;   -- loading of ACAM config reg 4 with rst word (local reset_word ->ACAM DAT_o)
                        else
                          nxt_engine_st   <= INACTIVE;
                        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      -- ACTIVE, GET_STAMP1, GET_STAMP2: intensive acquisition of timestamps from ACAM.
      -- ACAM can receive and tag pulses with an overall rate up to 31.25 MHz;
      -- therefore locally, running with a 125 MHz clk, in order to be able to receive timestamps
      -- as fast as they arrive, it is needed to use up to 4 clk cycles to retreive each of them.
      -- Timestamps are received as soon as the ef1, ef2 flags are at zero (indicating that the
      -- iFIFOs are not empty!). In order to avoid metastabilities locally, the ef signals are
      -- synchronized using a set of two registers.
      --    _______             ___________________________________________________
      --           |           |       ____                 ____
      --           |_____ef____|______|    |____ef_meta____|    |_____ef_synched
      --      ACAM |           |      |DFF1|               |DFF2|
      --           |           |      |\   |               |\   |
      --           |           |      |/___|               |/___|  
      --    _______|           |___________________________________________________
      --
      -- In the beginning the output of the second synchronizer flip-flop (ef_synch2) is used,
      -- as falling edges in the ef signals can arrive randomly at any moment and metastabilities
      -- could occur in the first flip-flop. On the other hand, after this first falling edge, the
      -- output ef_synch1 of the first flip-flop could be used since ef rising edges are not
      -- random any more and depend on the rdn signal generated locally by the
      -- acam_databus_interface unit. Following ACAM documentation (pg 7, Figure 2) 2 clk cycles
      -- = 16 ns after an rdn falling edge the ef_synch1 should be stable.
      -- 
      -- Using the ef_synch1 signal instead of the ef_synch2 makes it possible to realise
      -- timestamps' aquisitions from ACAM in just 4 clk cycles.
      -- clk           --|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__
      -- ef            ------|_______________________________________________________|--------------
      -- ef_meta       -----------|_____________________________________________________|-----------
      -- ef_synched    -----------------|_____________________________________________________|-----
      -- stb           _______________________|-----------------------------------------------|_____
      -- adr           _______________________| iFIFO adr set
      -- rdn           -----------------------------|_________________|-----|_______________________
      -- data valid                                             ^                       ^                    
      -- ack           _________________________________________|-----|_________________|-----|_____
      -- data retrieval                                               ^                       ^
      -- ef check                                                                             ^

      -- It is first checked if iFIFO1 is not empty, and if so a timestamp is retreived from it.
      -- Then iFIFO2 is checked and if it is not empty a timestamp is retreived from it.
      -- The alternation between the two FIFOs takes place until they are both empty.
      -- The retreival of a timestamp from any of the FIFOs takes place

      when WAIT_START_FROM_FPGA => -- wait until the start_from_fpga_p_o is sent (according to the utc_p)
                  -----------------------------------------------
                        acam_cyc        <= '0';
                        acam_stb        <= '0';
                        acam_we         <= '0';
                        time_c_en       <= '0';
                        time_c_rst      <= '1';
						-----------------------------------------------

                        if start_from_fpga_i = '1' then
                          nxt_engine_st <= WAIT_FOR_START01;
                        else
                          nxt_engine_st <= WAIT_START_FROM_FPGA;
                        end if;




      when WAIT_FOR_START01 => -- wait for some time until the acam Start01 is available
                  -----------------------------------------------
                        acam_cyc        <= '0';
                        acam_stb        <= '0';
                        acam_we         <= '0';
                        time_c_en       <= '1';
                        time_c_rst      <= '0';
						-----------------------------------------------

                        if time_c = x"00004000" then
                          nxt_engine_st <= RD_START01;
                        else
                          nxt_engine_st <= WAIT_FOR_START01;
                        end if;



      when RD_START01 => -- read now the acam Start01
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '0';
                        time_c_en       <= '1';
						time_c_rst      <= '0';
                  -----------------------------------------------

                        if acam_ack_i ='1' then
                          nxt_engine_st <= WAIT_UTC;
                        else
                          nxt_engine_st <= RD_START01;
                        end if;
						
						
      when WAIT_UTC => -- wait until the next utc comes; now the offsets of the start_retrig_ctrl unit are defined
	                   -- the acam is disabled during this period
                  -----------------------------------------------
                        acam_cyc        <= '0';
                        acam_stb        <= '0';
                        acam_we         <= '0';
                        time_c_en       <= '1';
						time_c_rst      <= '0';
						-----------------------------------------------

                        if time_c_full_p ='1' then
                          nxt_engine_st <= ACTIVE;
                        else
                          nxt_engine_st <= WAIT_UTC;
                        end if;						


      when ACTIVE =>
                  -----------------------------------------------
                        acam_cyc        <= '0';
                        acam_stb        <= '0';
                        acam_we         <= '0';
                        time_c_en       <= '0';
         				time_c_rst      <= '1';
                  -----------------------------------------------

                        if deactivate_acq_p_i = '1' then
                          nxt_engine_st   <= INACTIVE;

                        elsif acam_ef1_i = '0' then -- new tstamp in iFIFO1
                          nxt_engine_st   <= GET_STAMP1;

                        elsif acam_ef2_i = '0' then -- new tstamp in iFIFO2
                          nxt_engine_st   <= GET_STAMP2;

                        else
                          nxt_engine_st   <= ACTIVE;
                        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when GET_STAMP1 =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '0';
                  -----------------------------------------------
                        time_c_en <= '0';
                        time_c_rst <= '0';
                        
                        if deactivate_acq_p_i = '1' then
                          nxt_engine_st   <= INACTIVE;

                        elsif acam_ack_i ='1' then

                          if acam_ef2_i = '0' then
                            nxt_engine_st <= GET_STAMP2;
  
                          elsif acam_ef1_meta_i ='0' then
                            nxt_engine_st <= GET_STAMP1;
                          else
                            nxt_engine_st <= ACTIVE;
                          end if;

                        else
                          nxt_engine_st   <= GET_STAMP1;
                        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when GET_STAMP2 =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '0';
                                                time_c_en <= '0';
                        time_c_rst <= '0';

                  -----------------------------------------------

                        if deactivate_acq_p_i = '1' then
                          nxt_engine_st   <= INACTIVE;

                        elsif acam_ack_i ='1' then

                          if acam_ef1_i ='0' then
                            nxt_engine_st <= GET_STAMP1;

                          elsif acam_ef2_meta_i ='0' then
                            nxt_engine_st <= GET_STAMP2;
                          else
                            nxt_engine_st <= ACTIVE;
                          end if;

                        else
                          nxt_engine_st   <= GET_STAMP2;
                        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when WR_CONFIG =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '1';
                                                time_c_en <= '0';
                        time_c_rst <= '0';

                  -----------------------------------------------

                        if acam_ack_i = '1' and acam_adr = x"0E" then  -- last address
                          nxt_engine_st   <= INACTIVE;
                        else
                          nxt_engine_st   <= WR_CONFIG;
                        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when RDBK_CONFIG =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '0';
                                                time_c_en <= '0';
                        time_c_rst <= '0';

                  -----------------------------------------------

                        if acam_ack_i = '1' and acam_adr = x"0E" then  -- last address
                          nxt_engine_st   <= INACTIVE;
                        else
                          nxt_engine_st   <= RDBK_CONFIG;
                        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when RD_STATUS =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '0';
                  -----------------------------------------------

                        if acam_ack_i ='1' then
                          nxt_engine_st   <= INACTIVE;
                        else
                          nxt_engine_st   <= RD_STATUS;
                        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --      
      when RD_IFIFO1 =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '0';
                                                time_c_en <= '0';
                        time_c_rst <= '0';

                  -----------------------------------------------

                        if acam_ack_i ='1' then
                          nxt_engine_st   <= INACTIVE;
                        else
                          nxt_engine_st   <= RD_IFIFO1;
                        end if;


      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when RD_IFIFO2 =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '0';
                                                time_c_en <= '0';
                        time_c_rst <= '0';

                  -----------------------------------------------

                        if acam_ack_i ='1' then
                          nxt_engine_st   <= INACTIVE;
                        else
                          nxt_engine_st   <= RD_IFIFO2;
                        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when WR_RESET =>
                  -----------------------------------------------
                        acam_cyc        <= '1';
                        acam_stb        <= '1';
                        acam_we         <= '1';
                                                time_c_en <= '0';
                        time_c_rst <= '0';

                  -----------------------------------------------

                        if acam_ack_i ='1' then
                          nxt_engine_st   <= INACTIVE;
                        else
                          nxt_engine_st   <= WR_RESET;
                        end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when others =>
                  -----------------------------------------------
                        acam_cyc        <= '0';
                        acam_stb        <= '0';
                        acam_we         <= '0';
                                                time_c_en <= '0';
                        time_c_rst <= '0';

                  -----------------------------------------------

                        nxt_engine_st     <= INACTIVE;
        end case;
    end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --
  acam_cyc_o <= acam_cyc;
  acam_stb_o <= acam_stb;
  acam_we_o  <= acam_we;


---------------------------------------------------------------------------------------------------
--                  Address generation (acam_adr_o) for ACAM readings/ writings                  --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- adr_generation: according to the state of the FSM this process generates the acam_adr_o output
-- that specifies the ACAM register or FIFO to write to/read from.

  adr_generation: process (engine_st, config_adr_c)
  begin
    case engine_st is
      when INACTIVE   =>
                        acam_adr  <= x"00";

      when ACTIVE     =>
                        acam_adr  <= x"00";

      when GET_STAMP1 =>
                        acam_adr  <= std_logic_vector(c_ACAM_REG8_ADR);  -- FIFO1: ACAM reg 8

      when GET_STAMP2 =>
                        acam_adr  <= std_logic_vector(c_ACAM_REG9_ADR);  -- FIFO2: ACAM reg 9

      when WR_CONFIG  =>
                        acam_adr  <= std_logic_vector(config_adr_c);     -- sweeps through ACAM reg 0-7, 11, 12, 14

      when RDBK_CONFIG=>
                        acam_adr  <= std_logic_vector(config_adr_c);     -- sweeps through ACAM reg 0-7, 11, 12, 14

      when RD_STATUS  =>
                        acam_adr  <= std_logic_vector(c_ACAM_REG12_ADR); -- status: ACAM reg 12

      when RD_IFIFO1  =>
                        acam_adr  <= std_logic_vector(c_ACAM_REG8_ADR);  -- FIFO1: ACAM reg 8

      when RD_IFIFO2  =>
                        acam_adr  <= std_logic_vector(c_ACAM_REG9_ADR);  -- FIFO2: ACAM reg 9

      when RD_START01 =>
                        acam_adr  <= std_logic_vector(c_ACAM_REG10_ADR); -- START01: ACAM reg 10

      when WR_RESET   =>
                        acam_adr  <= std_logic_vector(c_ACAM_REG4_ADR);  -- reset: ACAM reg 4

      when others     =>
                        acam_adr  <= x"00";
    end case;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --
  acam_adr_o          <= acam_adr;


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- config_adr_c: counter used for the sweeping though the ACAM configuration addresses.
  -- counter counting: 0-> 1-> 2-> 3-> 4-> 5-> 6-> 7-> 11-> 12-> 14
  config_adr_counter: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i = '1' or acam_wr_config_p_i = '1' or acam_rdbk_config_p_i = '1' then
        config_adr_c   <= unsigned (c_ACAM_REG0_ADR);
        
      elsif acam_ack_i ='1' then
        if config_adr_c = unsigned (c_ACAM_REG14_ADR) then
          config_adr_c <= unsigned (c_ACAM_REG14_ADR);

        elsif config_adr_c = unsigned (c_ACAM_REG12_ADR) then
          config_adr_c <= unsigned (c_ACAM_REG14_ADR);

        elsif config_adr_c = unsigned (c_ACAM_REG7_ADR) then
          config_adr_c <= unsigned (c_ACAM_REG11_ADR);

        else
          config_adr_c <= config_adr_c + 1;
        end if;
      end if;

    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                          Values (acam_dat_o) for ACAM config writings                         --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- data_config_decoder: according to the acam_adr this process generates the acam_dat_o output
-- with the new value to be loaded to the corresponding ACAM reg. The values come from the
-- acam_config_i vector that keeps what has been loaded from the GN4124 interface.

  data_config_decoder: process(acam_adr, engine_st, acam_config_i, reset_word)
  begin
    case acam_adr is

      when c_ACAM_REG0_ADR  =>
        acam_dat_o   <= acam_config_i(0);

      when c_ACAM_REG1_ADR  =>
        acam_dat_o   <= acam_config_i(1);

      when c_ACAM_REG2_ADR  =>
        acam_dat_o   <= acam_config_i(2);

      when c_ACAM_REG3_ADR  =>
        acam_dat_o   <= acam_config_i(3);

      when c_ACAM_REG4_ADR  =>       -- in reg 4 there are bits (0-21, 24-27) defining normal config settings
                                     -- and there are also bits (22&23) initiating ACAM resets
        if engine_st = WR_RESET then
          acam_dat_o <= reset_word;

        else
          acam_dat_o <= acam_config_i(4);
        end if;

      when c_ACAM_REG5_ADR  =>
        acam_dat_o   <= acam_config_i(5);

      when c_ACAM_REG6_ADR  =>
        acam_dat_o   <= acam_config_i(6);

      when c_ACAM_REG7_ADR  =>
        acam_dat_o   <= acam_config_i(7);

      when c_ACAM_REG11_ADR =>
        acam_dat_o   <= acam_config_i(8);

      when c_ACAM_REG12_ADR =>
        acam_dat_o   <= acam_config_i(9);

      when c_ACAM_REG14_ADR =>
        acam_dat_o   <= acam_config_i(10);

      when others =>
        acam_dat_o   <= (others =>'0');
      end case;
    end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  acam_config_reg4   <= acam_config_i(4);
  reset_word         <= acam_config_reg4(31 downto 24) & "01" & acam_config_reg4(21 downto 0);
                     -- reg 4 bit 22: MasterReset :'1' = general reset excluding config regs 
                     -- reg 4 bit 23: PartialReset: would initiate a general reset excluding
                     --                             config regs&FIFOs, but this option is not used


---------------------------------------------------------------------------------------------------
--                      Aquisition of ACAM Timestamps or Reedback Registers                      --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- data_readback_decoder: after reading accesses to the ACAM (acam_we=0), the process recuperates
-- the ACAM data and according to the acam_adr_o stores them to the corresponding registers.
-- In the case of timestamps aquisition, the acam_tstamp1_ok_p_o, acam_tstamp2_ok_p_o pulses are
-- generated that when active, indicate a valid timestamp. Note that for timing reasons
-- the signals acam_tstamp1_o, acam_tstamp2_o are not the outputs of flip-flops.

  data_readback_decoder: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then
        acam_config_rdbk(0)    <= (others => '0');
        acam_config_rdbk(1)    <= (others => '0');
        acam_config_rdbk(2)    <= (others => '0');
        acam_config_rdbk(3)    <= (others => '0');
        acam_config_rdbk(4)    <= (others => '0');
        acam_config_rdbk(5)    <= (others => '0');
        acam_config_rdbk(6)    <= (others => '0');
        acam_config_rdbk(7)    <= (others => '0');
        acam_config_rdbk(8)    <= (others => '0');
        acam_config_rdbk(9)    <= (others => '0');
        acam_config_rdbk(10)   <= (others => '0');
        acam_ififo1_o          <= (others => '0');
        acam_ififo2_o          <= (others => '0');
        acam_start01_o         <= (others => '0');

      elsif acam_cyc = '1' and acam_stb = '1' and acam_ack_i = '1' and acam_we = '0' then

        if acam_adr = c_ACAM_REG0_ADR then
          acam_config_rdbk(0)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG1_ADR then
          acam_config_rdbk(1)  <= acam_dat_i;
        end if;
        if acam_adr = c_ACAM_REG2_ADR then
          acam_config_rdbk(2)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG3_ADR then
          acam_config_rdbk(3)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG4_ADR then
          acam_config_rdbk(4)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG5_ADR then
          acam_config_rdbk(5)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG6_ADR then
          acam_config_rdbk(6)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG7_ADR then
          acam_config_rdbk(7)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG11_ADR then
          acam_config_rdbk(8)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG12_ADR then
          acam_config_rdbk(9)  <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG14_ADR then
          acam_config_rdbk(10) <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG8_ADR then
          acam_ififo1_o        <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG9_ADR then
          acam_ififo2_o        <= acam_dat_i;
        end if;

        if acam_adr = c_ACAM_REG10_ADR then
          acam_start01_o       <= acam_dat_i;
        end if;

      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  acam_tstamp1_o               <= acam_dat_i;
  acam_tstamp1_ok_p_o          <= '1' when (acam_ack_i ='1' and engine_st = GET_STAMP1) else '0';

  acam_tstamp2_o               <= acam_dat_i;
  acam_tstamp2_ok_p_o          <= '1' when (acam_ack_i ='1' and engine_st = GET_STAMP2) else '0';

  acam_config_rdbk_o           <= acam_config_rdbk;



  time_counter: incr_counter
  generic map
    (width             => 32)
  port map
    (clk_i             => clk_i,
     rst_i             => time_c_rst,
     counter_top_i     => x"0EE6B280",
     counter_incr_en_i => time_c_en,
     counter_is_full_o => time_c_full_p,
     counter_o         => time_c);

  state_active_p_o <= time_c_full_p;

end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
