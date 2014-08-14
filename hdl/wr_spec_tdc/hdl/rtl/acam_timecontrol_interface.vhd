--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                    acam_timecontrol_interface                                  |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         acam_timecontrol_interface.vhd                                                    |
--                                                                                                |
-- Description  interface with the ACAM chip pins for control and timing.                         |
--              the start pulse is sent only once upon the activation of the acquisition,         |
--              synchronously to the utc_p_i                                                      |
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
--     05/2011  v0.1  GP  First version                                                           |
--     04/2012  v0.11 EG  Revamping; Comments added, signals renamed                              |
--     04/2014  v2    EG  Changed the generation of the start_from_fpga; synchronous to utc_p and |
--                        after the signalling from the data_engine that state_active_p_i         |
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
use IEEE.STD_LOGIC_1164.all; -- std_logic definitions
use IEEE.NUMERIC_STD.all;    -- conversion functions-- Specific library
-- Specific library
library work;
use work.tdc_core_pkg.all;   -- definitions of types, constants, entities
use work.gencores_pkg.all;


--=================================================================================================
--                       Entity declaration for acam_timecontrol_interface
--=================================================================================================

entity acam_timecontrol_interface is
  port
  -- INPUTS
    -- Signals from the clk_rst_manager unit
    (clk_i                   : in std_logic; -- 125 MHz clock
     rst_i                   : in std_logic; -- reset
     acam_refclk_r_edge_p_i  : in std_logic; -- pulse upon ACAM RefClk rising edge

    -- upc_p from the WRabbit or the local generator 
     utc_p_i                 : in std_logic;

    -- Signals from the data_engine unit
     state_active_p_i        : in std_logic; -- the core ready to follow the ACAM EF

    -- Signals from the reg_ctrl unit
     activate_acq_p_i        : in std_logic; -- signal from GN4124/VME to start following the ACAM chip
                                             -- for tstamps aquisition
	 deactivate_acq_p_i      : in std_logic; -- acquisition deactivated

    -- Signals from the ACAM chip
     err_flag_i              : in std_logic; -- ACAM error flag, active HIGH; through ACAM config
                                             -- reg 11 is set to report for any HitFIFOs full flags
     int_flag_i              : in std_logic; -- ACAM interrupt flag, active HIGH; through ACAM config
                                             -- reg 12 it is set to the MSB of Start#

  -- OUTPUTS
    -- Signals to the ACAM chip
     start_from_fpga_o       : out std_logic;

     stop_dis_o              : out std_logic; 	
    -- Signals to the 
     acam_errflag_r_edge_p_o : out std_logic; -- ACAM ErrFlag rising edge
     acam_errflag_f_edge_p_o : out std_logic; -- ACAM ErrFlag falling edge
     acam_intflag_f_edge_p_o : out std_logic);-- ACAM IntFlag falling edge

end acam_timecontrol_interface;

--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of acam_timecontrol_interface is

  signal int_flag_synch, err_flag_synch                          : std_logic_vector(2 downto 0);
  signal acam_intflag_f_edge_p                                   : std_logic;
  signal start_pulse, wait_for_utc, rst_n, wait_for_state_active : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--                            IntFlag and ERRflag Input Synchronizers                            --
---------------------------------------------------------------------------------------------------   

 rst_n <= not(rst_i);

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  sync_err_flag: process (clk_i)     -- synchronisation registers for ERR external signal
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then
        err_flag_synch <= (others => '0');
        int_flag_synch <= (others => '0');

      else
        err_flag_synch <= err_flag_i & err_flag_synch(2 downto 1);
        int_flag_synch <= int_flag_i & int_flag_synch(2 downto 1);
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  acam_errflag_f_edge_p_o   <= not(err_flag_synch(1)) and err_flag_synch(0);
  acam_errflag_r_edge_p_o   <= err_flag_synch(1) and not(err_flag_synch(0));

  acam_intflag_f_edge_p     <= not(int_flag_synch(1)) and int_flag_synch(0);
  acam_intflag_f_edge_p_o   <= acam_intflag_f_edge_p; 


---------------------------------------------------------------------------------------------------
--                                  start_from_fpga_o generation                                 --
---------------------------------------------------------------------------------------------------
-- send the start_from_fpga_o after the activate_acq_p_i (coming from the reg_ctrl unit) and
-- after the state_active_p_i (coming from the data_engine unit).
-- The pulse is synchronous to the utc_p_i

  start_pulse_from_fpga: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' or deactivate_acq_p_i = '1' then
        wait_for_utc            <= '0';
        start_pulse             <= '0';
        wait_for_state_active   <= '0';
        stop_dis_o              <= '1';
	  else
        if activate_acq_p_i = '1' then
          wait_for_utc          <= '1';
          start_pulse           <= '0';
        elsif utc_p_i = '1' and wait_for_utc = '1' then
          wait_for_utc          <= '0';
          start_pulse           <= '1';
		  wait_for_state_active <= '1';
		elsif wait_for_state_active = '1' and state_active_p_i = '1' then -- data_engine starts following ACAM EF
          stop_dis_o            <= '0'; 
		  wait_for_state_active <= '0';
		else
          start_pulse           <= '0';
        end if;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  extend_pulse : gc_extend_pulse
  generic map (g_width => 4)
  port map
    (clk_i      => clk_i,
     rst_n_i    => rst_n,
     pulse_i    => start_pulse,
     extended_o => start_from_fpga_o);


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
