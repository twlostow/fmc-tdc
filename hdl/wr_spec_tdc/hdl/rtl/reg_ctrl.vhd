--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                           reg_ctrl                                             |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         reg_ctrl.vhd                                                                      |
--                                                                                                |
-- Description  Interfaces with the GN4124/VME core for the configuration of the ACAM chip and of |
--              the TDC core. Data transfers take place between the GN4124/VME interface and      |
--              locally the TDC core. The unit implements a WISHBONE slave.                       |
--                                                                                                |
--              Through WISHBONE writes, the unit receives:                                       |
--                o the ACAM configuration registers which are then made available to the         |
--                  data_engine and acam_databus_interface units to be transfered to the ACAM chip|
--                o the local configuration registers (eg irq_thresholds, channels_enable) that   |
--                  are then made available to the different units of this design                 |
--                o the control register that defines the action to be taken in the core; the     |
--                  register is decoded and the corresponding signals are made available to the   |
--                  different units in the design.                                                |
--                                                                                                |
--              Through WISHBONE reads, the unit transmits:                                       |
--                o the ACAM configuration registers readback from the ACAM chip                  |
--                o status registers coming from different units of the TDC core                  |
--                                                                                                |
--              All the registers are of size 32 bits, as the WISHBONE data bus                   |
--                                                                                                |
--                                                                                                |
-- Authors      Gonzalo Penacoba  (Gonzalo.Penacoba@cern.ch)                                      |
--              Evangelia Gousiou (Evangelia.Gousiou@cern.ch)                                     |
-- Date         08/2012                                                                           |
-- Version      v1                                                                                |
-- Depends on                                                                                     |
--                                                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     10/2011  v0.1  GP  First version                                                           |
--     04/2012  v0.11 EG  Revamping; Comments added, signals renamed                              |
--     08/2012  v1    EG  added register reg_adr_pipe0 for slack timing reasons                   |
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
--                            Entity declaration for reg_ctrl
--=================================================================================================

entity reg_ctrl is
  generic
    (g_span                : integer := 32;
     g_width               : integer := 32);
  port
  -- INPUTS
     -- Signals from the clks_rsts_manager unit
    (clk_i                 : in std_logic;                             -- 125 MHz
     rst_i                 : in std_logic;                             -- global reset, synched to clk_i

     -- Signals from the GN4124/VME_core unit: WISHBONE for regs transfer
     tdc_config_wb_adr_i   : in std_logic_vector(g_span-1 downto 0);   -- WISHBONE address
     tdc_config_wb_cyc_i   : in std_logic;                             -- WISHBONE cycle
     tdc_config_wb_dat_i   : in std_logic_vector(g_width-1 downto 0);  -- WISHBONE data in
     tdc_config_wb_stb_i   : in std_logic;                             -- WISHBONE strobe
     tdc_config_wb_we_i    : in std_logic;                             -- WISHBONE write enable

     -- Signals from the data_engine unit: configuration regs read back from the ACAM
     acam_config_rdbk_i    : in config_vector;                         -- array keeping values read back from ACAM regs 0-7, 11, 12, 14
     acam_ififo1_i         : in std_logic_vector(g_width-1 downto 0);  -- keeps value read back from ACAM reg 8; for debug reasons only
     acam_ififo2_i         : in std_logic_vector(g_width-1 downto 0);  -- keeps value read back from ACAM reg 9; for debug reasons only
     acam_start01_i        : in std_logic_vector(g_width-1 downto 0);  -- keeps value read back from ACAM reg 10; for debug reasons only

     -- Signals from the data_formatting unit
     wr_index_i            : in std_logic_vector(g_width-1 downto 0);  -- index of the last circular_buffer adr written

     -- Signals from the one_hz_gen unit
     local_utc_i           : in std_logic_vector(g_width-1 downto 0);  -- local utc time

     -- Signals not used so far
     core_status_i         : in std_logic_vector(g_width-1 downto 0);  -- TDC core status word
     irq_code_i            : in std_logic_vector(g_width-1 downto 0);  -- TDC core interrupt code word

     -- White Rabbit status
     wrabbit_status_reg_i  : in std_logic_vector(g_width-1 downto 0);  -- 


  -- OUTPUTS
     -- Signals to the GN4124/VME_core unit: WISHBONE for regs transfer
     tdc_config_wb_ack_o   : out std_logic;                            -- WISHBONE acknowledge
     tdc_config_wb_dat_o   : out std_logic_vector(g_width-1 downto 0); -- WISHBONE data out

     -- Signals to the data_engine unit: config regs for the ACAM
     acam_config_o         : out config_vector;

     -- Signals to the data_engine unit: TDC core functionality
     activate_acq_p_o      : out std_logic;                            -- activates tstamps aquisition from ACAM
     deactivate_acq_p_o    : out std_logic;                            -- activates ACAM configuration readings/ writings
     acam_wr_config_p_o    : out std_logic;                            -- enables writing to ACAM regs 0-7, 11, 12, 14 
     acam_rdbk_config_p_o  : out std_logic;                            -- enables reading of ACAM regs 0-7, 11, 12, 14 
     acam_rst_p_o          : out std_logic;                            -- enables writing the c_RESET_WORD to ACAM reg 4
     acam_rdbk_status_p_o  : out std_logic;                            -- enables reading of ACAM reg 12 
     acam_rdbk_ififo1_p_o  : out std_logic;                            -- enables reading of ACAM reg 8
     acam_rdbk_ififo2_p_o  : out std_logic;                            -- enables reading of ACAM reg 9
     acam_rdbk_start01_p_o : out std_logic;                            -- enables reading of ACAM reg 10

     -- Signal to the data_formatting unit
     dacapo_c_rst_p_o      : out std_logic;                            -- clears the dacapo counter
	 deactivate_chan_o     : out std_logic_vector(4 downto 0);         -- stops registering timestamps from a specific channel

     -- Signals to the clks_resets_manager unit
     send_dac_word_p_o     : out std_logic;                            -- initiates the reconfiguration of the DAC
     dac_word_o            : out std_logic_vector(23 downto 0);

     -- Signal to the one_hz_gen unit
     load_utc_p_o          : out std_logic;
     starting_utc_o        : out std_logic_vector(g_width-1 downto 0);
     irq_tstamp_threshold_o: out std_logic_vector(g_width-1 downto 0); -- threshold in number of timestamps
     irq_time_threshold_o  : out std_logic_vector(g_width-1 downto 0); -- threshold in number of ms
     one_hz_phase_o        : out std_logic_vector(g_width-1 downto 0); -- for debug only

     -- Signal to the TDC mezzanine board
     acam_inputs_en_o      : out std_logic_vector(g_width-1 downto 0); -- enables all five input channels

     -- White Rabbit control
     wrabbit_ctrl_reg_o    : out std_logic_vector(g_width-1 downto 0);  -- 

     -- Signal to the acam_timecontrol_interface unit -- eva: i think it s not needed
     start_phase_o         : out std_logic_vector(g_width-1 downto 0));

end reg_ctrl;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of reg_ctrl is

  signal acam_config                                  : config_vector;
  signal reg_adr,reg_adr_pipe0                        : std_logic_vector(7 downto 0);
  signal starting_utc, acam_inputs_en, start_phase    : std_logic_vector(g_width-1 downto 0);
  signal ctrl_reg, one_hz_phase, irq_tstamp_threshold : std_logic_vector(g_width-1 downto 0);
  signal irq_time_threshold                           : std_logic_vector(g_width-1 downto 0);
  signal clear_ctrl_reg, send_dac_word_p              : std_logic;
  signal dac_word                                     : std_logic_vector(23 downto 0);
  signal pulse_extender_en                            : std_logic;
  signal pulse_extender_c                             : std_logic_vector(2 downto 0);
  signal dat_out, wrabbit_ctrl_reg, deactivate_chan   : std_logic_vector(g_span-1 downto 0);
  signal tdc_config_wb_ack_o_pipe0                    : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

  reg_adr <= tdc_config_wb_adr_i(7 downto 0); -- we are interested in addresses 0:5000 to 0:50FC

---------------------------------------------------------------------------------------------------
--                                WISHBONE ACK to GN4124/VME_core                                --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- TDCconfig_ack_generator: generation of the WISHBONE acknowledge signal for the
-- interactions with the GN4124/VME_core.

  TDCconfig_ack_generator: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i = '1' then
        tdc_config_wb_ack_o <= '0';
        tdc_config_wb_ack_o_pipe0 <= '0';
      elsif(tdc_config_wb_cyc_i = '0') then
        tdc_config_wb_ack_o <= '0';
        tdc_config_wb_ack_o_pipe0 <= '0';
      else
        tdc_config_wb_ack_o <= tdc_config_wb_ack_o_pipe0;
        tdc_config_wb_ack_o_pipe0 <= tdc_config_wb_stb_i and tdc_config_wb_cyc_i;
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                           Reception of ACAM Configuration Registers                           --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- ACAM_config_reg_reception: reception from the GN4124/VME interface of the configuration registers
-- to be loaded to the ACAM chip. The received data is stored in the acam_config vector which is
-- input to the data_engine and the acam_databus_interface units for the further transfer to the
-- ACAM chip.

  ACAM_config_reg_reception: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i = '1' then
        acam_config(0)    <= (others =>'0');
        acam_config(1)    <= (others =>'0');
        acam_config(2)    <= (others =>'0');
        acam_config(3)    <= (others =>'0');
        acam_config(4)    <= (others =>'0');
        acam_config(5)    <= (others =>'0');
        acam_config(6)    <= (others =>'0');
        acam_config(7)    <= (others =>'0');
        acam_config(8)    <= (others =>'0');
        acam_config(9)    <= (others =>'0');
        acam_config(10)   <= (others =>'0');

      elsif tdc_config_wb_cyc_i = '1' and tdc_config_wb_stb_i = '1' and tdc_config_wb_we_i = '1' then -- WISHBONE writes

        if reg_adr = c_ACAM_REG0_ADR then
          acam_config(0)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG1_ADR then
          acam_config(1)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG2_ADR then
          acam_config(2)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG3_ADR then
          acam_config(3)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG4_ADR then
          acam_config(4)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG5_ADR then
          acam_config(5)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG6_ADR then
          acam_config(6)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG7_ADR then
          acam_config(7)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG11_ADR then
          acam_config(8)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG12_ADR then
          acam_config(9)  <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_REG14_ADR then
          acam_config(10) <= tdc_config_wb_dat_i;
        end if;
      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --  
  acam_config_o  <= acam_config;


---------------------------------------------------------------------------------------------------
--                         Reception of TDC core Configuration Registers                         --
---------------------------------------------------------------------------------------------------
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- TDCcore_config_reg_reception: reception from the GN4124/VME interface of the configuration
-- registers to be loaded locally.
-- The following information is received:
--   o acam_inputs_en       : for the activation of the TDC input channels
--   o irq_tstamp_threshold : for the activation of GN4124/VME interrupts based on the number of timestamps
--   o irq_time_threshold   : for the activation of GN4124/VME interrupts based on the time elapsed
--   o starting_utc         : definition of the current UTC time
--   o starting_utc         : definition of the current UTC time
--   o one_hz_phase         : eva: think it s not used
--   o start_phase          : eva: think it s not used

  TDCcore_config_reg_reception: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i ='1' then
        acam_inputs_en       <= (others =>'0');
        starting_utc         <= (others =>'0');
        start_phase          <= (others =>'0');
        one_hz_phase         <= (others =>'0');
        irq_tstamp_threshold <= x"00000100";        -- default 256 timestamps: full memory
        irq_time_threshold   <= x"000000C8";        -- default 200 ms
        dac_word             <= c_DEFAULT_DAC_WORD; -- default DAC Vout = 1.65


      elsif tdc_config_wb_cyc_i = '1' and tdc_config_wb_stb_i = '1' and tdc_config_wb_we_i = '1' then -- WISHBONE writes

        if reg_adr = c_STARTING_UTC_ADR then
          starting_utc         <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ACAM_INPUTS_EN_ADR then
          acam_inputs_en       <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_START_PHASE_ADR then
          start_phase          <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_ONE_HZ_PHASE_ADR then
          one_hz_phase         <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_IRQ_TSTAMP_THRESH_ADR then
          irq_tstamp_threshold <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_IRQ_TIME_THRESH_ADR then
          irq_time_threshold   <= tdc_config_wb_dat_i;
        end if;

        if reg_adr = c_DAC_WORD_ADR then
          dac_word             <= tdc_config_wb_dat_i(23 downto 0);
        end if;

        if reg_adr = c_WRABBIT_CTRL_ADR then
          wrabbit_ctrl_reg    <= tdc_config_wb_dat_i;
        end if;
		
		if reg_adr = c_DEACT_CHAN_ADR then
          deactivate_chan     <= tdc_config_wb_dat_i;
        end if;

      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --
  starting_utc_o               <= starting_utc;
  acam_inputs_en_o             <= acam_inputs_en;
  start_phase_o                <= start_phase;
  one_hz_phase_o               <= one_hz_phase;
  irq_tstamp_threshold_o       <= irq_tstamp_threshold;
  irq_time_threshold_o         <= irq_time_threshold;
  dac_word_o                   <= dac_word;
  wrabbit_ctrl_reg_o           <= wrabbit_ctrl_reg;
  deactivate_chan_o            <= deactivate_chan(4 downto 0);

---------------------------------------------------------------------------------------------------
--                             Reception of TDC core Control Register                            --
---------------------------------------------------------------------------------------------------    
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- TDCcore_ctrl_reg_reception: reception from the GN4124/VME interface of the control register that
-- defines the action to be taken by the TDC core.
-- Note that only one bit of the register should be written at a time. The process receives
-- the register, defines the action to be taken and after 1 clk cycle clears the register. 
    
  TDCcore_ctrl_reg_reception: process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i = '1' then
        ctrl_reg         <= (others =>'0');
        clear_ctrl_reg   <= '0';

      elsif clear_ctrl_reg = '1' then
        ctrl_reg         <= (others =>'0');
        clear_ctrl_reg   <= '0';

      elsif tdc_config_wb_cyc_i = '1' and tdc_config_wb_stb_i = '1' and tdc_config_wb_we_i = '1' then -- WISHBONE writes
        if reg_adr = c_CTRL_REG_ADR then
          ctrl_reg       <= tdc_config_wb_dat_i;
          clear_ctrl_reg <= '1';
        end if;

      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --  --  --  --  --   
  activate_acq_p_o       <= ctrl_reg(0);
  deactivate_acq_p_o     <= ctrl_reg(1);
  acam_wr_config_p_o     <= ctrl_reg(2);
  acam_rdbk_config_p_o   <= ctrl_reg(3);
  acam_rdbk_status_p_o   <= ctrl_reg(4);
  acam_rdbk_ififo1_p_o   <= ctrl_reg(5);
  acam_rdbk_ififo2_p_o   <= ctrl_reg(6);
  acam_rdbk_start01_p_o  <= ctrl_reg(7);
  acam_rst_p_o           <= ctrl_reg(8);
  load_utc_p_o           <= ctrl_reg(9);
  dacapo_c_rst_p_o       <= ctrl_reg(10) or ctrl_reg(1); -- dacapo register reset when the acquisition is deactivated
  send_dac_word_p        <= ctrl_reg(11);
-- ctrl_reg bits 12 to 31 not used for the moment!

  --  --  --  --  --  --  --  --  --  --  --  --   
-- Pulse_stretcher: Increases the width of the send_dac_word_p pulse so that it can be sampled
-- by the 20 MHz clock of the clks_rsts_manager that is communicating with the DAC.

  Pulse_stretcher: incr_counter
  generic map
    (width             => 3)
  port map
    (clk_i             => clk_i,
     rst_i             => send_dac_word_p,
     counter_top_i     => "111",
     counter_incr_en_i => pulse_extender_en,
     counter_is_full_o => open,
     counter_o         => pulse_extender_c);
  --  --  --  --  --  --  --  --  --  --  --  --   
  pulse_extender_en     <= '1' when pulse_extender_c < "111" else '0';
  send_dac_word_p_o     <= pulse_extender_en;


---------------------------------------------------------------------------------------------------
--                        Delivery of ACAM and TDC core Readback Registers                       --
---------------------------------------------------------------------------------------------------   
-- TDCcore_ctrl_reg_reception: Delivery to the GN4124/VME interface of all the readable registers,
-- including those of the ACAM and the TDC core.
-- Note: pipelining of the address for timing/slack reasons 

  WISHBONEreads: process (clk_i)
  begin
    if rising_edge (clk_i) then
      --if tdc_config_wb_cyc_i = '1' and tdc_config_wb_stb_i = '1' and tdc_config_wb_we_i = '0' then -- WISHBONE reads
      --  tdc_config_wb_dat_o <= dat_out;
      reg_adr_pipe0       <= reg_adr;
      tdc_config_wb_dat_o <= dat_out;
      --end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  with reg_adr_pipe0 select dat_out <= 
    -- regs written by the GN4124/VME interface
    acam_config(0)         when c_ACAM_REG0_ADR,
    acam_config(1)         when c_ACAM_REG1_ADR,
    acam_config(2)         when c_ACAM_REG2_ADR,
    acam_config(3)         when c_ACAM_REG3_ADR,
    acam_config(4)         when c_ACAM_REG4_ADR,
    acam_config(5)         when c_ACAM_REG5_ADR,
    acam_config(6)         when c_ACAM_REG6_ADR,
    acam_config(7)         when c_ACAM_REG7_ADR,
    acam_config(8)         when c_ACAM_REG11_ADR,
    acam_config(9)         when c_ACAM_REG12_ADR,
    acam_config(10)        when c_ACAM_REG14_ADR,
    -- regs read from the ACAM
    acam_config_rdbk_i(0)  when c_ACAM_REG0_RDBK_ADR,
    acam_config_rdbk_i(1)  when c_ACAM_REG1_RDBK_ADR,
    acam_config_rdbk_i(2)  when c_ACAM_REG2_RDBK_ADR,
    acam_config_rdbk_i(3)  when c_ACAM_REG3_RDBK_ADR,
    acam_config_rdbk_i(4)  when c_ACAM_REG4_RDBK_ADR,
    acam_config_rdbk_i(5)  when c_ACAM_REG5_RDBK_ADR,
    acam_config_rdbk_i(6)  when c_ACAM_REG6_RDBK_ADR,
    acam_config_rdbk_i(7)  when c_ACAM_REG7_RDBK_ADR,
    acam_ififo1_i          when c_ACAM_REG8_RDBK_ADR,
    acam_ififo2_i          when c_ACAM_REG9_RDBK_ADR,
    acam_start01_i         when c_ACAM_REG10_RDBK_ADR,
    acam_config_rdbk_i(8)  when c_ACAM_REG11_RDBK_ADR,
    acam_config_rdbk_i(9)  when c_ACAM_REG12_RDBK_ADR,
    acam_config_rdbk_i(10) when c_ACAM_REG14_RDBK_ADR,
    -- regs written by the GN4124/VME interface
    starting_utc           when c_STARTING_UTC_ADR,
    acam_inputs_en         when c_ACAM_INPUTS_EN_ADR,
    start_phase            when c_START_PHASE_ADR,
    one_hz_phase           when c_ONE_HZ_PHASE_ADR,
    irq_tstamp_threshold   when c_IRQ_TSTAMP_THRESH_ADR,
    irq_time_threshold     when c_IRQ_TIME_THRESH_ADR,
    x"00" & dac_word       when c_DAC_WORD_ADR,
    -- regs written locally by the TDC core units
    local_utc_i            when c_LOCAL_UTC_ADR,
    irq_code_i             when c_IRQ_CODE_ADR,
    wr_index_i             when c_WR_INDEX_ADR,
    core_status_i          when c_CORE_STATUS_ADR,
    -- White Rabbit regs
    wrabbit_status_reg_i   when c_WRABBIT_STATUS_ADR,
    wrabbit_ctrl_reg       when c_WRABBIT_CTRL_ADR, 
    deactivate_chan        when c_DEACT_CHAN_ADR,
    -- others
    x"C0FFEEEE"            when others;


end architecture rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------