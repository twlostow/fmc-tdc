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
-- Description  interface with the ACAM chip pins for control and timing                          |
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

     utc_p_i                 : in std_logic; ----------------
     state_active_p_i        : in std_logic;
	 deactivate_acq_p_i      : in std_logic; --

    -- Signals from the ACAM chip
     err_flag_i              : in std_logic; -- ACAM error flag, active HIGH; through ACAM config
                                             -- reg 11 is set to report for any HitFIFOs full flags
     int_flag_i              : in std_logic; -- ACAM interrupt flag, active HIGH; through ACAM config
                                             -- reg 12 it is set to the MSB of Start#
    -- Signals from the reg_ctrl unit
     activate_acq_p_i        : in std_logic; -- signal from GN4124/VME to start following the ACAM chip
                                             -- for tstamps aquisition
     window_delay_i          : in std_logic_vector(31 downto 0); -- eva: not needed


  -- OUTPUTS
    -- Signals to the ACAM chip
     start_from_fpga_o       : out std_logic;

     stop_dis_o              : out   std_logic; 	
    -- Signals to the 
     acam_errflag_r_edge_p_o : out std_logic; -- ACAM ErrFlag rising edge
     acam_errflag_f_edge_p_o : out std_logic; -- ACAM ErrFlag falling edge
     acam_intflag_f_edge_p_o : out std_logic);-- ACAM IntFlag falling edge

end acam_timecontrol_interface;

--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of acam_timecontrol_interface is

  constant constant_delay : unsigned(31 downto 0) := x"00000004";
  -- the delay between the referenc clock and the start window is the Total Delay
  -- the Total delay is always obtained by adding the constant delay and the
  -- window delay configured by the PCI-e
  -- the start_from_fpga_o signal is generated in the middle of the start window

  signal counter_reset                             : std_logic;
  signal total_delay, counter_value                : std_logic_vector(31 downto 0);
  signal int_flag_synch, err_flag_synch            : std_logic_vector(2 downto 0);
  signal start_trig_received, waitingfor_refclk_i  : std_logic;
  signal window_start, window_prepulse             : std_logic;

  signal start_trig_r         : std_logic_vector(2 downto 0);
  signal start_trig_edge      : std_logic;
  signal start_pulse, wait_for_utc, rst_n, acam_intflag_f_edge_p, wait_for_state_active   : std_logic;


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
-- send the pulse upon the utc

  start_pulse_from_fpga: process (clk_i)                  -- start pulse in the middle of the
  begin                                                   -- de-assertion window of StartDisable
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
		elsif wait_for_state_active = '1' and state_active_p_i = '1' then -- data_engine starts following acam ef
          stop_dis_o            <= '0'; 
		  wait_for_state_active <= '0';
		else
          start_pulse           <= '0';
        end if;
      end if;
    end if;
  end process;

  extend_pulse : gc_extend_pulse
  generic map (g_width => 4)
  port map
    (clk_i      => clk_i,
     rst_n_i    => rst_n,
     pulse_i    => start_pulse,
     extended_o => start_from_fpga_o);

---------------------------------------------------------------------------------------------------
--                                  start_from_fpga_o generation                                 --
---------------------------------------------------------------------------------------------------   
-- Generation of the start pulse and the enable window:
-- the start pulse originates from an internal signal at the same time, the StartDis is de-asserted.
-- After many tests with the ACAM chip, the start Disable feature doesn't seem to be stable.
-- It has therefore been decided to avoid its usage. The generation of the window is maintained
-- to allow the control of the delay between the Start_From_FPGA pulse and the ACAM RefClk edge

  window_delayer_counter: decr_counter               -- all signals are synchronized
  generic map                                        -- to the refclk_i of the ACAM
    (width             => 32)                        -- But their delays are configurable.
  port map
    (clk_i             => clk_i,
     rst_i             => rst_i,
     counter_top_i     => total_delay,
     counter_load_i    => window_prepulse,
     counter_is_zero_o => window_start,
     counter_o         => open);
 
  window_prepulse      <= waitingfor_refclk_i and acam_refclk_r_edge_p_i;   


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
  window_active_counter: incr_counter                -- Defines the de-assertion window
  generic map                                        -- for the StartDisable signal
    (width             => 32)
  port map
    (clk_i             => clk_i,
     rst_i             => counter_reset,
     counter_top_i     => x"00000004",
     counter_incr_en_i => start_trig_received,

     counter_is_full_o => open,
     counter_o         => counter_value);

  counter_reset        <= rst_i or window_start;
  total_delay          <= std_logic_vector(unsigned(window_delay_i)+constant_delay);

    
  -- start_pulse_from_fpga: process (clk_i)                  -- start pulse in the middle of the
  -- begin                                                   -- de-assertion window of StartDisable
    -- if rising_edge (clk_i) then
      -- if rst_i ='1' then
        -- start_from_fpga_o <= '0';

      -- elsif counter_value >= x"00000001" and counter_value <= x"00000002" then
        -- start_from_fpga_o <= '1';

      -- else
        -- start_from_fpga_o <= '0';
      -- end if;
    -- end if;
  -- end process;


  -- Synchronization of the activate_acq_p with the acam_refclk_p_i
  ready_to_trigger: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then  
        waitingfor_refclk_i <= '0';

      elsif start_trig_edge ='1' then
        waitingfor_refclk_i <= '1';

      elsif acam_refclk_r_edge_p_i ='1' then
        waitingfor_refclk_i <= '0';

      end if;
    end if;
  end process;


  actual_trigger_received: process (clk_i)        -- signal needed to exclude the generation of
  begin                                           -- the start_from_fpga_o after a general rst_i
    if rising_edge (clk_i) then
      if rst_i ='1' then  
        start_trig_received <= '0';

      elsif window_start ='1' then
        start_trig_received <= '1';

      elsif counter_value = x"00000004" then
        start_trig_received <= '0';
      end if;

    end if;
  end process;


    start_trig_pulse: process (clk_i)
    begin
      if rising_edge (clk_i) then
        if rst_i ='1' then
          start_trig_r <= (others=>'0');
        else
          start_trig_r <= activate_acq_p_i & start_trig_r(2 downto 1);
        end if;
      end if;
    end process;

    start_trig_edge    <= start_trig_r(1) and not(start_trig_r(0));


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
