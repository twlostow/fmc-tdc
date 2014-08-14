--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                       clks_rsts_manager                                        |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         clks_rsts_manager.vhd                                                             |
--                                                                                                |
-- Description  Independent block that uses the clk_sys_i to parametrize the PLL and DAC on the   |
--              TDC mezzanine.                                                                    |
--                                                                                                |
--              The PLL is programmed to generate a 125 MHz clock that arrives to the FPGA and    |
--              is used by all the other units of the TDC core.                                   |
--              It is also programmed to generates a 31.25 MHz clock which is the reference clock |
--              for the ACAM chip.                                                                |
--              The registers for programming the PLL are hard-coded in this unit.                |
--                                                                                                |
--              Regarding the DAC, it needs one 23-bit-long word for its configuration. This      |
--              word along with the command for the configuration can be sent through the         |
--              PCIe/VME interface, or automatically through the White Rabbit core.               |
--                                                                                                |
--              Note that the PLL needs to be configured on the falling edges of the sclk clock,  |
--              whereas the DAC on the rising edges.                                              |
--                                                                                                |
--              The unit is also responsible for the generation of a global internal reset signal |
--              for the TDC core. This internal reset is triggered by a GN4124/VME interface      |
--              reset or by a Power On Reset at startup. The idea is to keep this reset asserted  |
--              until the 125 MHz clock signal received from the PLL is stable (PLL lock).        |
--                                                                                                |
--                                                                                                |
-- Authors      Gonzalo Penacoba  (Gonzalo.Penacoba@cern.ch)                                      |
--              Evangelia Gousiou (Evangelia.Gousiou@cern.ch)                                     |
-- Date         02/2014                                                                           |
-- Version      v1                                                                                |
-- Depends on                                                                                     |
--                                                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     05/2011  v0.1  GP  First version                                                           |
--     04/2012  v0.2  EG  Added DFFs to the pll_sdi_o, pll_cs_n_o outputs                         |
--                        Changed completely the internal reset generation; now it depends        |
--                        on the pll_status activation                                            |
--                        General revamping, comments added, signals renamed                      |
--     05/2012  v0.3  EG  Added logic for DAC configuration                                       |
--     02/2014  v1    EG  Correction for the DAC on rising edges; added wrabbit support           |
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
-- Specific libraries
library work;
use work.tdc_core_pkg.all;   -- definitions of types, constants, entities
library UNISIM;
use UNISIM.vcomponents.all;


--=================================================================================================
--                            Entity declaration for clks_rsts_manager
--=================================================================================================

entity clks_rsts_manager is
  generic
    (nb_of_reg              : integer := 68);
  port
  -- INPUTS
    -- Clock signal from carrier board
    (clk_sys_i              : in std_logic;                     -- 20MHz VCXO on carrier board or 62.5MHz from Xilinx PLL

    -- Clock signals from the TDC mezzanine PLL
     acam_refclk_p_i        : in std_logic;                     -- 31.25 MHz differential clock generated by
     acam_refclk_n_i        : in std_logic;                     -- the mezzanine PLL, same as ACAM's input clock
     tdc_125m_clk_p_i       : in std_logic;                     -- 125 MHz clock generated by the mezzanine PLL;
     tdc_125m_clk_n_i       : in std_logic;                     -- clock of all other TDC core logic

     -- Other signals from the TDC mezzanine PLL
     pll_status_i           : in std_logic;                     -- PLL lock detect
     pll_sdo_i              : in std_logic;                     -- not used

     -- Reset signal from the GN4124/VME interface
     rst_n_i                : in std_logic;                     -- GN4124/VME interface reset

     -- Signals from the reg_ctrl unit for the reconfiguration of the DAC
     send_dac_word_p_i      : in std_logic;                     -- pulse upon PCIe/VME request for a DAC reconfiguration
     dac_word_i             : in std_logic_vector(23 downto 0); -- DAC Vout = Vref (dac_word/65536)

     -- Signals from the White Rabbit unit for the reconfiguration of the DAC
     wrabbit_dac_value_i    : in    std_logic_vector(23 downto 0);
     wrabbit_dac_wr_p_i     : in    std_logic;

  -- OUTPUTS
     -- Signals to the rest of the modules of the TDC core
     tdc_125m_clk_o         : out std_logic;                    -- 125 MHZ clock
     internal_rst_o         : out std_logic;                    -- global reset, synched to tdc_125m_clk_o,
                                                                -- /!\ asserted until the 125 MHZ clock from the PLL becomes available

     -- Signals to the SPI interface for the PLL and DAC
     pll_cs_n_o             : out std_logic;                    -- SPI PLL chip select
     pll_dac_sync_n_o       : out std_logic;                    -- SPI DAC chip select
     pll_sdi_o              : out std_logic;                    -- SPI data
     pll_sclk_o             : out std_logic;                    -- SPI clock

     -- Signal to the one_hz_gen and acam_timecontrol_interface units
     acam_refclk_r_edge_p_o : out std_logic;                    -- pulse upon acam_refclk rising edge

     -- Signal to the leds_manager unit
     pll_status_o           : out std_logic);                   -- PLL lock detect

end clks_rsts_manager;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of clks_rsts_manager is

  -- PLL and DAC configuration state machine
  subtype t_wd        is std_logic_vector(15 downto 0);
  subtype t_byte      is std_logic_vector(7 downto 0);
  type t_instr        is array (nb_of_reg-1 downto 0) of t_wd;
  type t_stream       is array (nb_of_reg-1 downto 0) of t_byte;
  type t_pll_init_st  is (config_start, sending_dac_word, sending_pll_instruction, sending_pll_data, rest, done);
  signal nxt_config_st                             : t_pll_init_st;
  signal config_st                                 : t_pll_init_st := config_start;
  signal config_reg                                : t_stream;
  signal addr                                      : t_instr;
  signal pll_word_being_sent                       : t_wd;
  -- Counting of bits and bytes that are being sent
  signal pll_bit_being_sent, dac_bit_being_sent    : std_logic;
  signal bit_being_sent                            : std_logic;
  signal pll_bit_index                             : integer range 15 downto 0;
  signal pll_byte_index                            : integer range nb_of_reg-1 downto 0;
  signal dac_bit_index                             : integer range 23 downto 0;
  signal dac_word                                  : std_logic_vector(23 downto 0);
  signal send_dac_word_r_edge_p, dac_only          : std_logic;
  signal pll_cs_n, dac_cs_n                        : std_logic;
  -- Synchronizers
  signal pll_status_synch, internal_rst_synch      : std_logic_vector (1 downto 0);
  signal rst_in_synch                              : std_logic_vector (1 downto 0) := "11";
  signal acam_refclk_synch, send_dac_word_p_synch  : std_logic_vector (2 downto 0);
  -- Clock buffers
  signal tdc_clk_buf                               : std_logic;
  signal tdc_clk, acam_refclk                      : std_logic;
  -- Resets
  signal rst                                       : std_logic;
  signal rst_cnt                                   : unsigned(7 downto 0) := "00000000";
  -- SCLK generation
  signal sclk                                      : std_logic;
  signal sclk_r_edge, sclk_f_edge, sclk_d1, sclk_d2: std_logic;
  signal divider                                   : unsigned(7 downto 0) := "00000000";

-- The PLL circuit AD9516-4 needs to be configured through 68 registers.
-- The values and addresses are obtained through the dedicated Analog Devices software & the datasheet.
  constant REG_000 : t_byte := x"18";
  constant REG_001 : t_byte := x"00";
  constant REG_002 : t_byte := x"10";
  constant REG_003 : t_byte := x"C3";
  constant REG_004 : t_byte := x"00";

  constant REG_010 : t_byte := x"7C";
  constant REG_011 : t_byte := x"01";
  constant REG_012 : t_byte := x"00";
  constant REG_013 : t_byte := x"03";
  constant REG_014 : t_byte := x"09";
  constant REG_015 : t_byte := x"00";
  constant REG_016 : t_byte := x"04";
  constant REG_017 : t_byte := x"B4"; -- PLL_STATUS
  constant REG_018 : t_byte := x"07";
  constant REG_019 : t_byte := x"00";
  constant REG_01A : t_byte := x"00";
  constant REG_01B : t_byte := x"00";
  constant REG_01C : t_byte := x"02";
  constant REG_01D : t_byte := x"00";
  constant REG_01E : t_byte := x"00";
  constant REG_01F : t_byte := x"0E";

  constant REG_0A0 : t_byte := x"01";
  constant REG_0A1 : t_byte := x"00";
  constant REG_0A2 : t_byte := x"00";
  constant REG_0A3 : t_byte := x"01";
  constant REG_0A4 : t_byte := x"00";
  constant REG_0A5 : t_byte := x"00";
  constant REG_0A6 : t_byte := x"01";
  constant REG_0A7 : t_byte := x"00";
  constant REG_0A8 : t_byte := x"00";
  constant REG_0A9 : t_byte := x"01";
  constant REG_0AA : t_byte := x"00";
  constant REG_0AB : t_byte := x"00";

  constant REG_0F0 : t_byte := x"0A";
  constant REG_0F1 : t_byte := x"0A";
  constant REG_0F2 : t_byte := x"0A";
  constant REG_0F3 : t_byte := x"0A";
  constant REG_0F4 : t_byte := x"0A";
  constant REG_0F5 : t_byte := x"0A";

  constant REG_140 : t_byte := x"42"; -----REF_CLK
  constant REG_141 : t_byte := x"5A";
  constant REG_142 : t_byte := x"43";
  constant REG_143 : t_byte := x"42";

  constant REG_190 : t_byte := x"00";
  constant REG_191 : t_byte := x"80";
  constant REG_192 : t_byte := x"00";
  constant REG_193 : t_byte := x"00";
  constant REG_194 : t_byte := x"80";
  constant REG_195 : t_byte := x"00";
  constant REG_196 : t_byte := x"00";
  constant REG_197 : t_byte := x"80";
  constant REG_198 : t_byte := x"00";

  constant REG_199 : t_byte := x"22";
  constant REG_19A : t_byte := x"00";
  constant REG_19B : t_byte := x"11";
  constant REG_19C : t_byte := x"00";
  constant REG_19D : t_byte := x"00";
  constant REG_19E : t_byte := x"22";
  constant REG_19F : t_byte := x"00";

  constant REG_1A0 : t_byte := x"11";
  constant REG_1A1 : t_byte := x"20";
  constant REG_1A2 : t_byte := x"00";
  constant REG_1A3 : t_byte := x"00";

  constant REG_1E0 : t_byte := x"00";
  constant REG_1E1 : t_byte := x"02";

  constant REG_230 : t_byte := x"00";
  constant REG_231 : t_byte := x"00";
  constant REG_232 : t_byte := x"01";

  constant SIM_RST : std_logic_vector(31 downto 0):= x"00000400";
  constant SYN_RST : std_logic_vector(31 downto 0):= x"00004E20";
-- this value may still need adjustment according to the dispersion
-- in the performance of the PLL observed during the production tests


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin


---------------------------------------------------------------------------------------------------
--                                 Clock buffers instantiations                                  --
---------------------------------------------------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  tdc_clk125_ibuf : IBUFDS
  generic map
    (DIFF_TERM    => true,   -- Differential Termination
     IBUF_LOW_PWR => false,  -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
     IOSTANDARD   => "DEFAULT")
  port map
    (O  => tdc_clk_buf,      -- Buffer output
     I  => tdc_125m_clk_p_i, -- Diff_p buffer input (connect directly to top-level port)
     IB => tdc_125m_clk_n_i);-- Diff_n buffer input (connect directly to top-level port)

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  tdc_clk125_gbuf : BUFG
  port map
    (O => tdc_clk,
     I => tdc_clk_buf);
  --  --  --  --  --  --  --  --
  tdc_125m_clk_o  <= tdc_clk;


---------------------------------------------------------------------------------------------------
--                               Reset generation for 125 MHz logic                              --
---------------------------------------------------------------------------------------------------
-- The following processes generate an internal reset signal for the TDC mezzanine core.
-- This internal reset is triggered by a GN4124/VME interface reset or by a Power On Reset at startup.
-- The idea is to keep this reset asserted until the 125 MHz clock signal received from the TDC
-- mezzanine PLL is stable.

---------------------------------------------------------------------------------------------------
-- Synchronous process rst_n_i_synchronizer: Synchronization of the input reset signal rst_n_i,
-- coming from the GN4124/VME interface or a PoR, to the clk_sys_i, using a set of 2 registers.
-- Note that the removal of the reset signal is synchronised.
  PoR_synchronizer: process (clk_sys_i)
    begin
      if rising_edge (clk_sys_i) then
        rst_in_synch <= rst_in_synch(0) & not rst_n_i;
      end if;
    end process;

---------------------------------------------------------------------------------------------------
-- Synchronous process pll_status_synchronizer: Synchronization of the pll_status_i input to the
-- clk_sys_i, using a set of 2 registers.
  pll_status_synchronizer: process (clk_sys_i)
  begin
    if rising_edge (clk_sys_i) then
      if rst_in_synch(1) = '1' then
        pll_status_synch <= (others => '0');
      else
        pll_status_synch <= pll_status_synch(0) & pll_status_i;
      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --
  pll_status_o           <= pll_status_synch(1);


---------------------------------------------------------------------------------------------------
-- Synchronous process rst_generation: Generation of a reset signal for as long as the PLL
-- on the TDC board is not locked. As soon as the pll_status is received this internal reset
-- is released. Note that the level of the pll_status signal rather than its rising edge is used,
-- as in the case of a GN4124/VME reset during operation the PLL will remain locked, therefore no
-- rising edge would be detected.
  rst_generation: process (clk_sys_i)
  begin
    if rising_edge (clk_sys_i) then
      if rst_in_synch(1) = '1' then
        rst         <= '1';
      else
        if pll_status_synch(1) = '1' then
          if rst_cnt = "11111111" then
            rst     <= '0';
          else
            rst     <= '1';
            rst_cnt <= rst_cnt+1;
          end if;
        else
          rst       <= '1';
          rst_cnt   <= "00000000";
        end if;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
-- Synchronous process internal_rst_synchronizer: Synchronization of the above generated rst signal
-- to the 125MHz tdc_clk, using a set of 2 registers.
  Internal_rst_synchronizer: process (tdc_clk)
  begin
    if rising_edge (tdc_clk) then
      internal_rst_synch <= internal_rst_synch(0) & rst;
    end if;
  end process;
  --  --  --  --  --  --  --  --
  internal_rst_o         <= internal_rst_synch(1);


---------------------------------------------------------------------------------------------------
--                                      ACAM Reference Clock                                     --
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
  acam_refclk31M25_ibuf : IBUFDS
  generic map
    (DIFF_TERM    => true,  -- Differential Termination
     IBUF_LOW_PWR => false, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
     IOSTANDARD   => "DEFAULT")
  port map
    (O  => acam_refclk,
     I  => acam_refclk_p_i, -- Diff_p buffer input (connect directly to top-level port)
     IB => acam_refclk_n_i);-- Diff_n buffer input (connect directly to top-level port)

---------------------------------------------------------------------------------------------------
  acam_refclk_synchronizer: process (tdc_clk)
  begin
    if rising_edge (tdc_clk) then
      if internal_rst_synch(1) = '1' then
        acam_refclk_synch <= (others => '0');
      else
        acam_refclk_synch <= acam_refclk_synch(1 downto 0) & acam_refclk;
      end if;
    end if;
  end process;
  --  --  --  --  --  --
  acam_refclk_r_edge_p_o  <= (not acam_refclk_synch(2)) and acam_refclk_synch(1);


---------------------------------------------------------------------------------------------------
--                                       DAC configuration                                       --
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Synchronous process send_dac_word_p_synchronizer: Synchronization of the send_dac_word_p_o
-- input to the clk_sys_i, using a set of 3 registers.
  send_dac_word_p_synchronizer: process (clk_sys_i)
  begin
    if rising_edge (clk_sys_i) then
      if rst_in_synch(1) = '1' then
        send_dac_word_p_synch <= (others => '0');
      else
        send_dac_word_p_synch <= send_dac_word_p_synch(1 downto 0) & send_dac_word_p_i;
      end if;
    end if;
  end process;
  --  --  --  --  --  --  --  --
  send_dac_word_r_edge_p      <= (not send_dac_word_p_synch(2)) and send_dac_word_p_synch(1);

---------------------------------------------------------------------------------------------------
-- Synchronous process dac_word_reg: selection of the word to be sent to the DAC.
-- Upon initialization the default word is being sent; otherwise the word received through the VME
-- interface on the DAC_WORD register.
  dac_word_reg: process (clk_sys_i)
  begin
    if rising_edge (clk_sys_i) then
      if rst_in_synch(1)  = '1' then
        dac_word <= c_DEFAULT_DAC_WORD;
      elsif send_dac_word_r_edge_p = '1' then
        dac_word <= dac_word_i;
      elsif wrabbit_dac_wr_p_i = '1' then
        dac_word <= wrabbit_dac_value_i;
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                            FSM for configuration of the DAC and PLL                           --
---------------------------------------------------------------------------------------------------
-- Configuration of the PLL and of the DAC on the TDC mezzanine board.
-- The PLL is configured:
--   after the powering-up of the board or after a GN4124/VME reset (rst_n_i).
-- The DAC is configured:
--   after the powering-up of the board or after a GN4124/VME reset (rst_n_i) or
--   after a GN4124/VME command for the reconfiguration of the DAC  (send_dac_word_p_i) or
--   after a White Rabbit command for the reconfiguration of the DAC(wrabbit_dac_wr_p_i)
---------------------------------------------------------------------------------------------------
  pll_dac_initialization_seq: process (clk_sys_i)
  begin
    if rising_edge (clk_sys_i) then
      if rst_in_synch(1)  = '1' or send_dac_word_r_edge_p = '1' then
        config_st <= config_start;
        dac_only  <= '0';
      elsif  wrabbit_dac_wr_p_i = '1' then
        config_st <= config_start;
        dac_only  <= '1';
      else
        config_st <= nxt_config_st;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
  pll_dac_initialization_comb: process (config_st, dac_bit_index, pll_byte_index, pll_bit_index, sclk,
                                        sclk_r_edge, sclk_f_edge, dac_only)
  begin
    case config_st is

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when config_start =>
       -----------------------------------
          pll_cs_n          <= '1';
          dac_cs_n          <= '1';
       -----------------------------------
          if sclk_r_edge = '1' then
            nxt_config_st   <= sending_dac_word;
          else
            nxt_config_st   <= config_start;
          end if;

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when sending_dac_word =>
       -----------------------------------
          pll_cs_n          <= '1';
          dac_cs_n          <= '0';
       -----------------------------------
          if dac_bit_index = 0 and sclk_f_edge = '1' and dac_only = '0' then
            nxt_config_st   <= sending_pll_instruction;
          elsif dac_bit_index = 0 and sclk_f_edge = '1' and dac_only = '1' then
            nxt_config_st   <= done;
          else
            nxt_config_st   <= sending_dac_word;
          end if;

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when sending_pll_instruction =>
       -----------------------------------
          pll_cs_n          <= '0';
          dac_cs_n          <= '1';
       -----------------------------------
          if pll_bit_index = 0 and sclk_r_edge = '1' then
            nxt_config_st   <= sending_pll_data;
          else
            nxt_config_st   <= sending_pll_instruction;
          end if;

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when sending_pll_data =>
       -----------------------------------
          pll_cs_n          <= '0';
          dac_cs_n          <= '1';
       -----------------------------------
          if pll_bit_index = 0 and sclk_r_edge = '1' then
            nxt_config_st   <= rest;
          else
             nxt_config_st  <= sending_pll_data;
          end if;

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when rest =>
       -----------------------------------
          pll_cs_n          <= '1';
          dac_cs_n          <= '1';
       -----------------------------------
          if sclk_r_edge = '1' then
            if pll_byte_index = 0 then
              nxt_config_st <= done;
            else
              nxt_config_st <= sending_pll_instruction;
            end if;
          else
            nxt_config_st   <= rest;
          end if;

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when done =>
       -----------------------------------
          pll_cs_n          <= '1';
          dac_cs_n          <= '1';
       -----------------------------------
          nxt_config_st     <= done;

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
      when others =>
       -----------------------------------
          pll_cs_n          <= '1';
          dac_cs_n          <= '1';
       -----------------------------------
          nxt_config_st     <= config_start;

        end case;
    end process;

---------------------------------------------------------------------------------------------------
  pll_sclk_generator: process (clk_sys_i) -- transitions take place on the falling edge of sclk
  begin
    if rising_edge (clk_sys_i) then
      if rst_in_synch(1) = '1' then
        sclk    <= '0';
        sclk_d1 <= '0';
        sclk_d2 <= '0';
      else
        sclk_d1 <= sclk;
        sclk_d2 <= sclk_d1;
        if divider(2) = '1' then
          sclk  <= '0';
        else
          sclk  <= '1';
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  sclk_r_edge <= (not sclk_d2) and sclk_d1;
  sclk_f_edge <= sclk_d2 and (not sclk_d1);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_in_synch(1) = '1' then
        divider   <= (others => '0');
      else
        if(divider = "111") then
          divider <= (others => '0');
        else
          divider <= divider + 1;
        end if;
      end if;
    end if;
  end process;

---------------------------------------------------------------------------------------------------
  pll_index_control: process (clk_sys_i) -- counting of bits that are sent on the rising edges
  begin
    if rising_edge (clk_sys_i) then

      if rst_in_synch(1)  = '1' then
        pll_bit_index     <= 15;

      elsif pll_cs_n = '1' then
        pll_bit_index     <= 15;

      elsif sclk_r_edge = '1' then
        if pll_bit_index = 0 then
          pll_bit_index   <= 7;
        else
          pll_bit_index   <= pll_bit_index -1;
        end if;
      end if;

      if rst_in_synch(1)  = '1' then
        pll_byte_index    <= nb_of_reg -1;
      elsif config_st = rest and sclk_r_edge = '1' then
        if pll_byte_index = 0 then
          pll_byte_index  <= nb_of_reg-1;
        else
          pll_byte_index  <= pll_byte_index -1;
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  pll_bit_being_sent  <= pll_word_being_sent(pll_bit_index);
  pll_word_being_sent <= addr(pll_byte_index)  when config_st = sending_pll_instruction
                         else x"00" & config_reg(pll_byte_index);

---------------------------------------------------------------------------------------------------
  dac_index_control: process (clk_sys_i)
  begin
    if rising_edge (clk_sys_i) then -- counting of bits that are sent on the falling edges

      if rst_in_synch(1)  = '1' then
        dac_bit_index <= 23;

      elsif dac_cs_n = '1' and sclk_f_edge = '1' then
        dac_bit_index <= 23;

      elsif dac_cs_n = '0' and sclk_f_edge = '1' then
        if dac_bit_index = 0 then
          dac_bit_index   <= 23;
        else
          dac_bit_index <= dac_bit_index - 1;
        end if;
      end if;
    end if;
  end process;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  dac_bit_being_sent  <= dac_word(dac_bit_index);
  bit_being_sent      <= dac_bit_being_sent when dac_cs_n = '0' else pll_bit_being_sent;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  pll_sdi_o        <= bit_being_sent;
  pll_dac_sync_n_o <= dac_cs_n;
  pll_cs_n_o       <= pll_cs_n;
  pll_sclk_o       <= sclk_d1;


---------------------------------------------------------------------------------------------------
--            Assignment of the values to be sent for the configurations of the PLL              --
---------------------------------------------------------------------------------------------------
-- According to the data sheet the register 232 should be written last to validate the transfer
-- from the buffer to the valid registers. The 16-bit instruction word indicates always a write
-- cycle of byte.
-- -- -- -- -- -- -- -- -- -- -- -- -- --
  addr(0)        <= x"0232";
  addr(1)        <= x"0000";
  addr(2)        <= x"0001";
  addr(3)        <= x"0002";
  addr(4)        <= x"0003";
  addr(5)        <= x"0004";
  --------------------------
  addr(6)        <= x"0010";
  addr(7)        <= x"0011";
  addr(8)        <= x"0012";
  addr(9)        <= x"0013";
  addr(10)       <= x"0014";
  addr(11)       <= x"0015";
  addr(12)       <= x"0016";
  addr(13)       <= x"0017";
  addr(14)       <= x"0018";
  addr(15)       <= x"0019";
  addr(16)       <= x"001A";
  addr(17)       <= x"001B";
  addr(18)       <= x"001C";
  addr(19)       <= x"001D";
  addr(20)       <= x"001E";
  addr(21)       <= x"001F";
  --------------------------
  addr(22)       <= x"00A0";
  addr(23)       <= x"00A1";
  addr(24)       <= x"00A2";
  addr(25)       <= x"00A3";
  addr(26)       <= x"00A4";
  addr(27)       <= x"00A5";
  addr(28)       <= x"00A6";
  addr(29)       <= x"00A7";
  addr(30)       <= x"00A8";
  addr(31)       <= x"00A9";
  addr(32)       <= x"00AA";
  addr(33)       <= x"00AB";
  --------------------------
  addr(34)       <= x"00F0";
  addr(35)       <= x"00F1";
  addr(36)       <= x"00F2";
  addr(37)       <= x"00F3";
  addr(38)       <= x"00F4";
  addr(39)       <= x"00F5";
  --------------------------
  addr(40)       <= x"0140";
  addr(41)       <= x"0141";
  addr(42)       <= x"0142";
  addr(43)       <= x"0143";
  --------------------------
  addr(44)       <= x"0190";
  addr(45)       <= x"0191";
  addr(46)       <= x"0192";
  addr(47)       <= x"0193";
  addr(48)       <= x"0194";
  addr(49)       <= x"0195";
  addr(50)       <= x"0196";
  addr(51)       <= x"0197";
  addr(52)       <= x"0198";
  --------------------------
  addr(53)       <= x"0199";
  addr(54)       <= x"019A";
  addr(55)       <= x"019B";
  addr(56)       <= x"019C";
  addr(57)       <= x"019D";
  addr(58)       <= x"019E";
  addr(59)       <= x"019F";
  --------------------------
  addr(60)       <= x"01A0";
  addr(61)       <= x"01A1";
  addr(62)       <= x"01A2";
  addr(63)       <= x"01A3";
  --------------------------
  addr(64)       <= x"01E0";
  addr(65)       <= x"01E1";
  --------------------------
  addr(66)       <= x"0230";
  addr(67)       <= x"0231";
-- -- -- -- -- -- -- -- -- -- -- -- -- --
  config_reg(0)  <= REG_232;
  config_reg(1)  <= REG_000;
  config_reg(2)  <= REG_001;
  config_reg(3)  <= REG_002;
  config_reg(4)  <= REG_003;
  config_reg(5)  <= REG_004;
  --------------------------
  config_reg(6)  <= REG_010;
  config_reg(7)  <= REG_011;
  config_reg(8)  <= REG_012;
  config_reg(9)  <= REG_013;
  config_reg(10) <= REG_014;
  config_reg(11) <= REG_015;
  config_reg(12) <= REG_016;
  config_reg(13) <= REG_017;
  config_reg(14) <= REG_018;
  config_reg(15) <= REG_019;
  config_reg(16) <= REG_01A;
  config_reg(17) <= REG_01B;
  config_reg(18) <= REG_01C;
  config_reg(19) <= REG_01D;
  config_reg(20) <= REG_01E;
  config_reg(21) <= REG_01F;
  --------------------------
  config_reg(22) <= REG_0A0;
  config_reg(23) <= REG_0A1;
  config_reg(24) <= REG_0A2;
  config_reg(25) <= REG_0A3;
  config_reg(26) <= REG_0A4;
  config_reg(27) <= REG_0A5;
  config_reg(28) <= REG_0A6;
  config_reg(29) <= REG_0A7;
  config_reg(30) <= REG_0A8;
  config_reg(31) <= REG_0A9;
  config_reg(32) <= REG_0AA;
  config_reg(33) <= REG_0AB;
  --------------------------
  config_reg(34) <= REG_0F0;
  config_reg(35) <= REG_0F1;
  config_reg(36) <= REG_0F2;
  config_reg(37) <= REG_0F3;
  config_reg(38) <= REG_0F4;
  config_reg(39) <= REG_0F5;
  --------------------------
  config_reg(40) <= REG_140;
  config_reg(41) <= REG_141;
  config_reg(42) <= REG_142;
  config_reg(43) <= REG_143;
  --------------------------
  config_reg(44) <= REG_190;
  config_reg(45) <= REG_191;
  config_reg(46) <= REG_192;
  config_reg(47) <= REG_193;
  config_reg(48) <= REG_194;
  config_reg(49) <= REG_195;
  config_reg(50) <= REG_196;
  config_reg(51) <= REG_197;
  config_reg(52) <= REG_198;
  --------------------------
  config_reg(53) <= REG_199;
  config_reg(54) <= REG_19A;
  config_reg(55) <= REG_19B;
  config_reg(56) <= REG_19C;
  config_reg(57) <= REG_19D;
  config_reg(58) <= REG_19E;
  config_reg(59) <= REG_19F;
  --------------------------
  config_reg(60) <= REG_1A0;
  config_reg(61) <= REG_1A1;
  config_reg(62) <= REG_1A2;
  config_reg(63) <= REG_1A3;
  --------------------------
  config_reg(64) <= REG_1E0;
  config_reg(65) <= REG_1E1;
  --------------------------
  config_reg(66) <= REG_230;
  config_reg(67) <= REG_231;
-- -- -- -- -- -- -- -- -- -- -- -- -- --


end rtl;
----------------------------------------------------------------------------------------------------
--  architecture ends
----------------------------------------------------------------------------------------------------