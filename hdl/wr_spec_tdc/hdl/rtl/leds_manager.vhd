--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                         leds_manager                                           |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         leds_manager.vhd                                                                  |
--                                                                                                |
-- Description  Generation of the signals that drive the LEDs on the TDC mezzanine.               |
--              There are 6 LEDs on the front panel of the TDC mezzanine board:                   |
--                                        ______                                                  |
--                                       |      |                                                 |
--                                       | O  O |   1, 2                                          |
--                                       | O  O |   3, 4                                          |
--                                       | O  O |   5, 6                                          |
--                                       |______|                                                 |
--                                                                                                |
--              TDC LED  1 orange: division of the 125 MHz clock; one hz pulses                   |
--              TDC LED  2 orange: Channel 1 termination enable                                   |
--              TDC LED  3 orange: Channel 2 termination enable                                   |
--              TDC LED  4 orange: Channel 3 termination enable                                   |
--              TDC LED  5 orange: Channel 4 termination enable                                   |
--              TDC LED  6 orange: Channel 5 termination enable                                   |
--                                                                                                |
-- Authors      Gonzalo Penacoba  (Gonzalo.Penacoba@cern.ch)                                      |
-- Date         05/2012                                                                           |
-- Version      v0.1                                                                              |
-- Depends on                                                                                     |
--                                                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     05/2012  v0.1  EG  First version                                                           |
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
use IEEE.NUMERIC_STD.all;    -- conversion functions
-- Specific libraries
library work;
use work.tdc_core_pkg.all;   -- definitions of types, constants, entities
use work.gencores_pkg.all;



--=================================================================================================
--                            Entity declaration for leds_manager
--=================================================================================================

entity leds_manager is
  generic
    (g_width           : integer := 32;
     values_for_simul  : boolean := FALSE);
  port
  -- INPUTS
     -- Signals from the clks_rsts_manager
    (clk_i             : in std_logic;                            -- 125 MHz clock
     rst_i             : in std_logic;                            -- core internal reset, synched with 125 MHz clk

     -- Signal from the one_hz_generator unit
     utc_p_i           : in std_logic;

     -- Signal from the reg_ctrl unit
     acam_inputs_en_i  : in std_logic_vector(g_width-1 downto 0); -- enable for the ACAM channels;
                                                                  -- activation comes through dedicated reg c_ACAM_INPUTS_EN_ADR

     -- Signal for debugging
     acam_channel_i        : in std_logic_vector(5 downto 0);         -- for debugging, currently not used
     tstamp_wr_p_i     : in std_logic;


  -- OUTPUTS
     -- Signals to the LEDs on the TDC front panel
     tdc_led_status_o  : out std_logic;                           -- TDC  LED 1: division of 125 MHz
     tdc_led_trig1_o   : out std_logic;                           -- TDC  LED 2: Channel 1 termination enable
     tdc_led_trig2_o   : out std_logic;                           -- TDC  LED 3: Channel 2 termination enable
     tdc_led_trig3_o   : out std_logic;                           -- TDC  LED 4: Channel 3 termination enable
     tdc_led_trig4_o   : out std_logic;                           -- TDC  LED 5: Channel 4 termination enable
     tdc_led_trig5_o   : out std_logic);                          -- TDC  LED 6: Channel 5 termination enable

end leds_manager;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of leds_manager is

  signal tdc_led_blink_done                 : std_logic;
  signal visible_blink_length               : std_logic_vector(g_width-1 downto 0);
  signal rst_n, blink_led1, blink_led2      : std_logic;
  signal ch1, ch2, ch3, ch4, ch5            : std_logic;
  signal blink_led3, blink_led4, blink_led5 : std_logic;
  signal tstamp_wr_p, blink_led             : std_logic;
  signal acam_channel                       : std_logic_vector(5 downto 0);


begin
---------------------------------------------------------------------------------------------------
--                                     TDC FRONT PANEL LED 1                                     --
---------------------------------------------------------------------------------------------------  
  
---------------------------------------------------------------------------------------------------
  tdc_status_led_blink_counter: decr_counter
  port map
    (clk_i             => clk_i,
     rst_i             => rst_i,
     counter_load_i    => utc_p_i,
     counter_top_i     => visible_blink_length,
     counter_is_zero_o => tdc_led_blink_done,
     counter_o         => open);

---------------------------------------------------------------------------------------------------
  tdc_status_led_gener: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then
        tdc_led_status_o <= '0';
      elsif utc_p_i ='1' then
        tdc_led_status_o <= '1';
      elsif tdc_led_blink_done = '1' then
        tdc_led_status_o <= '0';
      end if;
    end if;
  end process;

  visible_blink_length <= c_BLINK_LGTH_SIM when values_for_simul else c_BLINK_LGTH_SYN;


---------------------------------------------------------------------------------------------------
--                                    TDC FRONT PANEL LEDs 2-6                                   --
--------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------
  rst_n <= not(rst_i);

  led_1to5_outputs: process (clk_i)
  begin
    if rising_edge (clk_i) then
      tdc_led_trig1_o  <= blink_led1; --acam_inputs_en_i(0) and blink_led1;
      tdc_led_trig2_o  <= blink_led2; --acam_inputs_en_i(1) and blink_led2;
      tdc_led_trig3_o  <= blink_led3; --acam_inputs_en_i(2) and blink_led3;
      tdc_led_trig4_o  <= blink_led4; --acam_inputs_en_i(3) and blink_led4;
      tdc_led_trig5_o  <= blink_led5; --acam_inputs_en_i(4) and blink_led5;
    end if;
  end process;


  pulse_generator: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i = '1' then
        acam_channel <= (others => '0');
        tstamp_wr_p  <= '0';
        ch1          <= '0';
        ch2          <= '0';
        ch3          <= '0';
        ch4          <= '0';
        ch5          <= '0';
      else
        acam_channel <= acam_channel_i;
        tstamp_wr_p  <= tstamp_wr_p_i;
        if tstamp_wr_p = '1' and acam_inputs_en_i(7) = '1' then
          if acam_channel(2 downto 0)    = "000" then
            ch1      <= '1';
            ch2      <= '0';
            ch3      <= '0';
            ch4      <= '0';
            ch5      <= '0';
          elsif acam_channel(2 downto 0) = "001" then
            ch1      <= '0';
            ch2      <= '1';
            ch3      <= '0';
            ch4      <= '0';
            ch5      <= '0';
          elsif acam_channel(2 downto 0) = "010" then
            ch1      <= '0';
            ch2      <= '0';
            ch3      <= '1';
            ch4      <= '0';
            ch5      <= '0';
          elsif acam_channel(2 downto 0) = "011" then
            ch1      <= '0';
            ch2      <= '0';
            ch3      <= '0';
            ch4      <= '1';
            ch5      <= '0';
          else
            ch1      <= '0';
            ch2      <= '0';
            ch3      <= '0';
            ch4      <= '0';
            ch5      <= '1';
          end if;
        else
          ch1      <= '0';
          ch2      <= '0';
          ch3      <= '0';
          ch4      <= '0';
          ch5      <= '0';
        end if;
      end if;
    end if;
  end process;

  cmp_extend_ch1_pulse: gc_extend_pulse
  generic map
    (g_width    => 5000000)
  port map
    (clk_i      => clk_i,
     rst_n_i    => rst_n,
     pulse_i    => ch1,
     extended_o => blink_led1);

  cmp_extend_ch2_pulse: gc_extend_pulse
  generic map
    (g_width    => 5000000)
  port map
    (clk_i      => clk_i,
     rst_n_i    => rst_n,
     pulse_i    => ch2,
     extended_o => blink_led2);

  cmp_extend_ch3_pulse: gc_extend_pulse
  generic map
    (g_width    => 5000000)
  port map
    (clk_i      => clk_i,
     rst_n_i    => rst_n,
     pulse_i    => ch3,
     extended_o => blink_led3);

  cmp_extend_ch4_pulse: gc_extend_pulse
  generic map
    (g_width    => 5000000)
  port map
    (clk_i      => clk_i,
     rst_n_i    => rst_n,
     pulse_i    => ch4,
     extended_o => blink_led4);

  cmp_extend_ch5_pulse: gc_extend_pulse
  generic map
    (g_width    => 5000000)
  port map
    (clk_i      => clk_i,
     rst_n_i    => rst_n,
     pulse_i    => ch5,
     extended_o => blink_led5);



end rtl;
----------------------------------------------------------------------------------------------------
--  architecture ends
----------------------------------------------------------------------------------------------------