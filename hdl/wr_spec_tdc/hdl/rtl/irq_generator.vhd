--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                         irq_generator                                          |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         irq_generator.vhd                                                                 |
--                                                                                                |
-- Description  Interrupts generator: the unit generates three interrups:                         |
--                                                                                                |
--                o irq_tstamp_p_o is a 1-clk_i-long pulse generated when the amount of           |
--                  timestamps written in the circular_buffer, since the last interrupt or since  |
--                  the startup of the aquisition, exceeds the GN4124/VME settable threshold      |
--                  irq_tstamp_threshold.                                                         |
--                                                                                                |
--                o irq_time_p_o is a 1-clk_i-long pulse generated when some timestamps have been |
--                  written in the circular_buffer (>=1 timestamp) and the amount of time passed  |
--                  since the last interrupt or since the aquisition startup, exceeds the         |
--                  GN4124/VME settable threshold irq_time_threshold. The threshold is in ms.     |
--                                                                                                |
--                o irq_acam_err_p_o is a 1-clk_i-long pulse generated when the ACAM Hit FIFOS are|
--                  full (according to ACAM configuration register 11)                            |
--                                                                                                |
--                                                                                                |
-- Authors      Gonzalo Penacoba  (Gonzalo.Penacoba@cern.ch)                                      |
--              Evangelia Gousiou (Evangelia.Gousiou@cern.ch)                                     |
-- Date         08/2013                                                                           |
-- Version      v1                                                                                |
-- Depends on                                                                                     |
--                                                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     05/2012  v0.1  EG  First version                                                           |
--     04/2013  v0.2  EG  line 170 added "irq_time_threshold_i > 0"; if the user doesn t want the |
--                        time interrupts he sets the irq_time_threshold reg to zero; same goes   |
--                        for number-of-tstamps interrupts, users sets to zero to disable them    |
--     08/2013  v1    EG  time irq concept in milliseconds rather than seconds                    |
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


--=================================================================================================
--                            Entity declaration for irq_generator
--=================================================================================================
entity irq_generator is
  generic
    (g_width                 : integer := 32);
  port
  -- INPUTS
     -- Signal from the clks_rsts_manager
    (clk_i                   : in std_logic;                            -- 125 MHz clk
     rst_i                   : in std_logic;                            -- global reset

     irq_tstamp_threshold_i  : in std_logic_vector(g_width-1 downto 0); -- GN4124/VME settable threshold
     irq_time_threshold_i    : in std_logic_vector(g_width-1 downto 0); -- GN4124/VME settable threshold

     -- Signal from the acam_timecontrol_interface
     acam_errflag_r_edge_p_i : in std_logic;                            -- ACAM ErrFlag rising edge; through the ACAM config reg 11
                                                                        -- the ERRflag is configured to follow the full flags of the
                                                                        -- Hit FIFOs; this would translate to data loss
     -- Signal from the reg_ctrl unit 
     activate_acq_p_i        : in std_logic;                            -- activates tstamps aquisition from ACAM
     deactivate_acq_p_i      : in std_logic;                            -- deactivates tstamps aquisition

     -- Signals from the data_formatting unit
     tstamp_wr_p_i           : in std_logic;                            -- pulse upon storage of a new timestamp


  -- OUTPUTS
     -- Signals to the wb_irq_controller
     irq_tstamp_p_o          : out std_logic;                           -- active if amount of tstamps > tstamps_threshold
     irq_time_p_o            : out std_logic;                           -- active if amount of tstamps < tstamps_threshold but time > time_threshold
     irq_acam_err_p_o        : out std_logic);                          -- active if ACAM err_flag_i is active

end irq_generator;

--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of irq_generator is

  constant ZERO                                     : std_logic_vector (8 downto 0):= "000000000";
  type t_irq_st is (IDLE, TSTAMP_AND_TIME_COUNTING, RAISE_IRQ_TSTAMP, RAISE_IRQ_TIME);
  signal irq_st, nxt_irq_st                         : t_irq_st;
  signal tstamps_c_rst, time_c_rst                  : std_logic;
  signal tstamps_c_en, time_c_en                    : std_logic;
  signal tstamps_c_incr_en, time_c_incr_en          : std_logic;
  signal tstamps_c                                  : std_logic_vector(8 downto 0); 
  signal time_c                                     : std_logic_vector(g_width-1 downto 0);
  signal one_ms_passed_p                            : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

---------------------------------------------------------------------------------------------------
--                                   INTERRUPTS GENERATOR FSM                                    --
---------------------------------------------------------------------------------------------------

  IRQ_generator_seq: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then
        irq_st <= IDLE;
      else
        irq_st <= nxt_irq_st;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
  IRQ_generator_comb: process (irq_st, activate_acq_p_i, deactivate_acq_p_i, tstamps_c,
                                  irq_tstamp_threshold_i, irq_time_threshold_i, time_c)
  begin
    case irq_st is

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when IDLE =>
                -----------------------------------------------
                   irq_tstamp_p_o <= '0';
                   irq_time_p_o   <= '0';
                   tstamps_c_rst  <= '1';
                   time_c_rst     <= '1';
                   tstamps_c_en   <= '0';
                   time_c_en      <= '0';
                -----------------------------------------------
                   if activate_acq_p_i = '1' then
                     nxt_irq_st   <= TSTAMP_AND_TIME_COUNTING;
                   else
                     nxt_irq_st   <= IDLE;
                   end if;

       --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when TSTAMP_AND_TIME_COUNTING =>
                -----------------------------------------------
                   irq_tstamp_p_o <= '0';
                   irq_time_p_o   <= '0';
                   tstamps_c_rst  <= '0';
                   time_c_rst     <= '0';
                   tstamps_c_en   <= '1';
                   time_c_en      <= '1';
                -----------------------------------------------
                   if deactivate_acq_p_i = '1' then
                     nxt_irq_st   <= IDLE;
                   elsif tstamps_c > ZERO and tstamps_c >= irq_tstamp_threshold_i(8 downto 0) then -- not >= ZERO!!
                     nxt_irq_st   <= RAISE_IRQ_TSTAMP;
                   elsif unsigned(irq_time_threshold_i) > 0 and time_c >= irq_time_threshold_i and tstamps_c > ZERO then
                     nxt_irq_st   <= RAISE_IRQ_TIME;
                   else
                     nxt_irq_st   <= TSTAMP_AND_TIME_COUNTING;
                   end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when RAISE_IRQ_TSTAMP =>
                -----------------------------------------------
                   irq_tstamp_p_o <= '1';
                   irq_time_p_o   <= '0';
                   tstamps_c_rst  <= '1';
                   time_c_rst     <= '1';
                   tstamps_c_en   <= '0';
                   time_c_en      <= '0';
                -----------------------------------------------
                   if deactivate_acq_p_i = '1' then
                     nxt_irq_st   <= IDLE;
                   else
                     nxt_irq_st   <= TSTAMP_AND_TIME_COUNTING;
                   end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when RAISE_IRQ_TIME =>
                -----------------------------------------------
                   irq_tstamp_p_o <= '0';
                   irq_time_p_o   <= '1';
                   tstamps_c_rst  <= '1';
                   time_c_rst     <= '1';
                   tstamps_c_en   <= '0';
                   time_c_en      <= '0';
                -----------------------------------------------
                   if deactivate_acq_p_i = '1' then
                     nxt_irq_st   <= IDLE;
                   else
                     nxt_irq_st   <= TSTAMP_AND_TIME_COUNTING;
                   end if;

      --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when others =>
                -----------------------------------------------
                   irq_tstamp_p_o <= '0';
                   irq_time_p_o   <= '0';
                   tstamps_c_rst  <= '1';
                   time_c_rst     <= '1';
                   tstamps_c_en   <= '0';
                   time_c_en      <= '0';
                -----------------------------------------------
                   nxt_irq_st     <= IDLE;
    end case;
  end process;


---------------------------------------------------------------------------------------------------
--                                      TIMESTAMPS COUNTER                                       --
---------------------------------------------------------------------------------------------------
-- Incremental counter counting the amount of timestamps written since the last interrupt or the
-- last reset. The counter counts up to 255.
  tstamps_counter: incr_counter
    generic map
      (width             => 9)--(c_CIRCULAR_BUFF_SIZE'length)) -- 9 digits, counting up to 255
    port map
      (clk_i             => clk_i,
       rst_i             => tstamps_c_rst,  
       counter_top_i     => "100000000",
       counter_incr_en_i => tstamps_c_incr_en,
       counter_is_full_o => open,
     -------------------------------------------
       counter_o         => tstamps_c);
     -------------------------------------------
    tstamps_c_incr_en    <= tstamps_c_en and tstamp_wr_p_i;


---------------------------------------------------------------------------------------------------
--                                         TIME COUNTER                                          --
---------------------------------------------------------------------------------------------------
-- Incremental counter counting the time in milliseconds since the last interrupt or the last reset.
  time_counter: incr_counter
    generic map
      (width             => g_width)
    port map
      (clk_i             => clk_i,
       rst_i             => time_c_rst,  
       counter_top_i     => x"FFFFFFFF",
       counter_incr_en_i => time_c_incr_en,
       counter_is_full_o => open,
     -------------------------------------------
       counter_o         => time_c);
     -------------------------------------------
    time_c_incr_en       <= time_c_en and one_ms_passed_p;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  millisec_counter: free_counter
    generic map
      (width             => g_width)
    port map
      (clk_i             => clk_i,
       rst_i             => rst_i,
       counter_en_i      => '1',
       counter_top_i     => x"0001E848", -- 125'000 clk_i cycles = 1 ms
      -------------------------------------------
       counter_is_zero_o => one_ms_passed_p,
       counter_o         => open);
      -------------------------------------------


---------------------------------------------------------------------------------------------------
--                                       ACAM ErrFlag IRQ                                        --
---------------------------------------------------------------------------------------------------
  irq_acam_err_p_o <= acam_errflag_r_edge_p_i;

    
end rtl;
----------------------------------------------------------------------------------------------------
--  architecture ends
----------------------------------------------------------------------------------------------------