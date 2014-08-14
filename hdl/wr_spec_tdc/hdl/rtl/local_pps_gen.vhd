--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        local_pps_gen                                           |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         local_pps_gen.vhd                                                                 |
--                                                                                                |
-- Description  Generates one pulse every second synchronously with the ACAM reference clock.     |
--              The phase with the reference clock can be adjusted (eva: think that is not needed)|
--              It also keeps track of the UTC time based on the local clock.                     |
--              If there is no White Rabbit synchronization, this unit is the source of UTC timing|
--              in the design.
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


--=================================================================================================
--                            Entity declaration for local_pps_gen
--=================================================================================================

entity local_pps_gen is
  generic
    (g_width                : integer := 32);
  port
  -- INPUTS
     -- Signals from the clk_rst_manager unit
    (clk_i                  : in std_logic;
     rst_i                  : in std_logic;  
     acam_refclk_r_edge_p_i : in std_logic;   
     clk_period_i           : in std_logic_vector(g_width-1 downto 0); -- nb of clock periods for 1s

     -- Signals from the reg_ctrl unit
     load_utc_p_i           : in std_logic; -- enables loading of the local UTC time with starting_utc_i value
     starting_utc_i         : in std_logic_vector(g_width-1 downto 0); -- value coming from the GN4124/VME
     pulse_delay_i          : in std_logic_vector(g_width-1 downto 0); -- nb of clock periods phase delay
                                                                       -- with respect to reference clock

  -- OUTPUTS
     -- Signal to data_formatting and reg_ctrl units
     local_utc_o            : out std_logic_vector(g_width-1 downto 0); -- tstamp current second

     -- Signal to start_retrig_ctrl unit
     local_utc_p_o          : out std_logic);                           -- pulse upon new second 

end local_pps_gen;

--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of local_pps_gen is

  constant constant_delay         : unsigned(g_width-1 downto 0) := x"00000004";
  signal local_utc                : unsigned(g_width-1 downto 0);
  signal one_hz_p_pre             : std_logic;
  signal one_hz_p_post            : std_logic;
  signal onesec_counter_en        : std_logic;
  signal total_delay              : std_logic_vector(g_width-1 downto 0);


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                         1 sec counting                                        --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- clk_periods_counter: generation of a 1 clk-long pulse every second.
-- The first pulse occurs one second after the startup of the acam_refclk
-- bits 27-31 not used.

  clk_periods_counter: free_counter
    generic map
      (width             => g_width)
    port map
      (clk_i             => clk_i,
       rst_i             => rst_i,
       counter_en_i      => onesec_counter_en,
       counter_top_i     => clk_period_i,
      -------------------------------------------
       counter_is_zero_o => one_hz_p_pre,
       counter_o         => open);
      -------------------------------------------

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --   
  clk_periods_counter_en_trigger: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then
        onesec_counter_en <= '0';

      elsif acam_refclk_r_edge_p_i ='1' then
        onesec_counter_en <= '1'; -- stays at 1 after the first acam_refclk pulse
      end if;

    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                                         Load UTC time                                         --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- utc_counter: generation of a 1 clk-long pulse every second

  utc_counter: process (clk_i)
  begin   
    if rising_edge (clk_i) then
      if rst_i ='1' then
        local_utc <= (others => '0');

      elsif load_utc_p_i = '1' then
        local_utc <= unsigned(starting_utc_i); -- loading of local_utc with incoming starting_utc_i

      elsif one_hz_p_post = '1' then           -- new second counted; local_utc updated
        local_utc <= local_utc + 1;

      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  local_utc_o     <= std_logic_vector(local_utc);


---------------------------------------------------------------------------------------------------
--                                            Delays                                             --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  pulse_delayer_counter: decr_counter -- delays the one_hz_p_pre pulse for total_delay clk_i ticks 
    generic map
      (width             => g_width)
    port map
      (clk_i             => clk_i,
       rst_i             => rst_i,
       counter_load_i    => one_hz_p_pre,
       counter_top_i     => total_delay,
      -------------------------------------------
       counter_is_zero_o => one_hz_p_post,
       counter_o         => open);
      -------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  total_delay       <= std_logic_vector(unsigned(pulse_delay_i)+constant_delay);
  local_utc_p_o     <= one_hz_p_post;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
