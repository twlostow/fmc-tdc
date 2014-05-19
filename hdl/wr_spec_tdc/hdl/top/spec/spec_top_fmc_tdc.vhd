--_________________________________________________________________________________________________
--                                                                                                |
--                                           |SPEC TDC|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        spec_top_fmc_tdc                                        |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         spec_top_fmc_tdc.vhd                                                              |
--                                                                                                |
-- Description  TDC top level for a SPEC carrier. Figure 1 shows the architecture of the unit.    |
--                                                                                                |
--              For the communication with the PCIe, the ohwr.org GN4124 core is instantiated.    |
--                                                                                                |
--              The TDC mezzanine core is instantiated for the communication with the TDC board.  |
--              The VIC core is forwarding the interrupts coming from the TDC mezzanine core to   |
--                the GN4124 core.                                                                |
--              The carrier_info module provides general information on the SPEC PCB version, PLLs |
--                locking state etc.                                                              |
--              The 1-Wire core provides communication with the SPEC Thermometer&UniqueID chip.   |
--              All the cores communicate with the GN4124 core through the SDB crossbar. The SDB  |
--              crossbar is responsible for managing the acess to the GN4124 core.                |
--                                                                                                |
--              The speed of all the cores (TDC mezzanine, VIC, carrier csr, 1-Wire as well as    |
--              the GN4124 core) is 125MHz.                                                       |
--                                                                                                |
--              The 125MHz clock comes from the PLL located on the TDC mezzanine board.           |
--              The clks_rsts_manager unit is responsible for automatically configuring the PLL   |
--              upon the FPGA startup or after a PCIe reset, using the 20MHz VCXO on the SPEC     |
--              carrier board. The clks_rsts_manager is keeping all the rest of the logic under   |
--              reset until the PLL gets locked.                                                  |
--                                                                                                |
--                __________________________________________________________________              |
--   ________    |                                           ___        _____       |             |
--  |        |   |            ___________________           |   |      |     |      |             |
--  |  PLL   |<->|           | clks rsts manager |          |   |      |     |      |             |
--  |  DAC   |   |           |___________________|          |   |      |     |      |             |
--  |        |   |       ____________________________       |   |      |     |      |             |
--  |        |   |      |                            | \    |   |      |     |      |             |
--  |  ACAM  |<->|      |       TDC mezzanine        |  \   |   |      |     |      |             |
--  |________|   |   |--|____________________________|   \  |   |      |  G  |      |             |
--   TDC mezz    |   |                                    \ |   |      |     |      |             |
--               |   |   ____________________________       | S |      |  N  |      |             |
--               |   |->|                            |      |   |      |     |      |             |
--               |      | Vector Interrupt Controller| ---- | D | <--> |  4  |      |             |
--               |      |____________________________|      |   |      |     |      |             |
--               |                                          | B |      |  1  |      |             |
--               |       ____________________________       |   |      |     |      |             |
--               |      |                            |      |   |      |  2  |      |             |
-- SPEC 1Wire <->|      |          1-Wire            | ---- |   |      |     |      |             |
--               |      |____________________________|      |   |      |  4  |      |             |
--               |                                        / |   |      |     |      |             |
--               |       ____________________________    /  |   |      |     |      |             |
--               |      |                            |  /   |   |      |     |      |             |
--               |      |        carrier_info         | /    |   |      |     |      |             |
--               |      |____________________________|      |   |      |     |      |             |
--               |                                          |___|      |_____|      |             |
--               |                                                                  |             |
--               |      ______________________________________________              |             |
-- SPEC LEDs  <->|     |___________________LEDs_______________________|             |             |
--               |                                                                  |             |
--               |__________________________________________________________________|             |
--                                                                                                |
--                                                                                                |
-- Authors      Gonzalo Penacoba  (Gonzalo.Penacoba@cern.ch)                                      |
--              Evangelia Gousiou (Evangelia.Gousiou@cern.ch)                                     |
-- Date         01/2014                                                                           |
-- Version      v5 (see sdb_meta_pkg)                                                             |
-- Depends on                                                                                     |
--                                                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     05/2011  v1  GP  First version                                                             |
--     06/2012  v2  EG  Revamping; Comments added, signals renamed                                |
--                      removed LEDs from top level                                               |
--                      new GN4124 core integrated                                                |
--                      carrier 1 wire master added                                               |
--                      mezzanine I2C master added                                                |
--                      mezzanine 1 wire master added                                             |
--                      interrupts generator added                                                |
--                      changed generation of rst_125m_mezz                                         |
--                      DAC reconfiguration+needed regs added                                     |
--     06/2012  v3  EG  Changes for v2 of TDC mezzanine                                           |
--                      Several pinout changes,                                                   |
--                      acam_ref_clk LVDS instead of CMOS,                                        |
--                      no PLL_LD only PLL_STATUS                                                 |
--     04/2013  v4  EG  added SDB; fixed bugs in data_formatting; added carrier CSR information   |
--     01/2014  v5  EG  added VIC and EIC in the TDC mezzanine                                    |
--                                                                                                |
----------------------------------------------/!\-------------------------------------------------|
-- Note for eva: Remember the design is synthesised with Synplify Premier with DP (tdc_syn.prj)   |
-- For PAR use the tdc_par_script.tcl commands in Xilinx ISE!                                     |
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
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tdc_core_pkg.all;
use work.gn4124_core_pkg.all;
use work.gencores_pkg.all;
use work.wishbone_pkg.all;
--use work.sdb_meta_pkg.all;
use work.wrcore_pkg.all;
use work.wr_fabric_pkg.all;
use work.wr_xilinx_pkg.all;

use work.synthesis_descriptor.all;

library UNISIM;
use UNISIM.vcomponents.all;

--=================================================================================================
--                            Entity declaration for spec_top_fmc_tdc
--=================================================================================================
entity spec_top_fmc_tdc is
  generic
    (g_span             : integer := 32;                      -- address span in bus interfaces
     g_width            : integer := 32;                      -- data width in bus interfaces
     values_for_simul   : boolean := FALSE);                  -- this generic is set to TRUE
                                                              -- when instantiated in a test-bench
  port
    (-- SPEC carrier
     clk_125m_pllref_p_i: in    std_logic;                    -- 125 MHz PLL reference
     clk_125m_pllref_n_i: in    std_logic;

     clk_125m_gtp_n_i   : in    std_logic;                    -- 125 MHz GTP reference
     clk_125m_gtp_p_i   : in    std_logic;

     clk_20m_vcxo_i     : in    std_logic;                    -- 20 MHz VCXO

     dac_sclk_o         : out   std_logic;                    -- PLL VCXO DAC Drive
     dac_din_o          : out   std_logic;
     dac_cs1_n_o        : out   std_logic;
     dac_cs2_n_o        : out   std_logic;

     sfp_txp_o          : out   std_logic;                    -- SFP
     sfp_txn_o          : out   std_logic;
     sfp_rxp_i          : in    std_logic := '0';
     sfp_rxn_i          : in    std_logic := '1';
     sfp_mod_def0_b     : in    std_logic; -- SFP detect pin
     sfp_mod_def1_b     : inout std_logic; -- SFP scl
     sfp_mod_def2_b     : inout std_logic; -- SFP sda
     sfp_rate_select_b  : inout std_logic := '0';
     sfp_tx_fault_i     : in    std_logic := '0';
     sfp_tx_disable_o   : out   std_logic;
     sfp_los_i          : in    std_logic := '0';

     uart_rxd_i         : in    std_logic := '1';             -- UART
     uart_txd_o         : out   std_logic;

     carrier_scl_b      : inout std_logic;             -- SPEC EEPROM
     carrier_sda_b      : inout std_logic;

     carrier_onewire_b  : inout std_logic;                    -- SPEC 1-wire

     button1_i          : in    std_logic := '1';
     button2_i          : in    std_logic := '1';

     -- Interface with GN4124
     rst_n_a_i          : in    std_logic;
     -- P2L Direction
     p2l_clk_p_i        : in    std_logic;                    -- Receiver Source Synchronous Clock+
     p2l_clk_n_i        : in    std_logic;                    -- Receiver Source Synchronous Clock-
     p2l_data_i         : in    std_logic_vector(15 downto 0);-- Parallel receive data
     p2l_dframe_i       : in    std_logic;                    -- Receive Frame
     p2l_valid_i        : in    std_logic;                    -- Receive Data Valid
     p2l_rdy_o          : out   std_logic;                    -- Rx Buffer Full Flag
     p_wr_req_i         : in    std_logic_vector(1 downto 0); -- PCIe Write Request
     p_wr_rdy_o         : out   std_logic_vector(1 downto 0); -- PCIe Write Ready
     rx_error_o         : out   std_logic;                    -- Receive Error
     vc_rdy_i           : in    std_logic_vector(1 downto 0); -- Virtual channel ready
     -- L2P Direction
     l2p_clk_p_o        : out   std_logic;                    -- Transmitter Source Synchronous Clock+ (freq set in GN4124 config registers)
     l2p_clk_n_o        : out   std_logic;                    -- Transmitter Source Synchronous Clock- (freq set in GN4124 config registers)
     l2p_data_o         : out   std_logic_vector(15 downto 0);-- Parallel transmit data
     l2p_dframe_o       : out   std_logic;                    -- Transmit Data Frame
     l2p_valid_o        : out   std_logic;                    -- Transmit Data Valid
     l2p_edb_o          : out   std_logic;                    -- Packet termination and discard
     l2p_rdy_i          : in    std_logic;                    -- Tx Buffer Full Flag
     l_wr_rdy_i         : in    std_logic_vector(1 downto 0); -- Local-to-PCIe Write
     p_rd_d_rdy_i       : in    std_logic_vector(1 downto 0); -- PCIe-to-Local Read Response Data Ready
     tx_error_i         : in    std_logic;                    -- Transmit Error
     irq_p_o            : out   std_logic;                    -- Interrupt request pulse to GN4124 GPIO 8
     irq_aux_p_o        : out   std_logic;                    -- Interrupt request pulse to GN4124 GPIO 9, aux signal

     -- Interface with the PLL AD9516 and DAC AD5662 on TDC mezzanine
     pll_sclk_o         : out   std_logic;                    -- SPI clock
     pll_sdi_o          : out   std_logic;                    -- data line for PLL and DAC
     pll_cs_o           : out   std_logic;                    -- PLL chip select
     pll_dac_sync_o     : out   std_logic;                    -- DAC chip select
     pll_sdo_i          : in    std_logic;                    -- not used for the moment
     pll_status_i       : in    std_logic;                    -- PLL Digital Lock Detect, active high
     tdc_clk_125m_p_i   : in    std_logic;                    -- 125 MHz differential clock: system clock
     tdc_clk_125m_n_i   : in    std_logic;                    -- 125 MHz differential clock: system clock
     acam_refclk_p_i    : in    std_logic;                    -- 31.25 MHz differential clock: ACAM ref clock
     acam_refclk_n_i    : in    std_logic;                    -- 31.25 MHz differential clock: ACAM ref clock

     -- Timing interface with the ACAM on TDC mezzanine
     start_from_fpga_o  : out   std_logic;                    -- start signal
     err_flag_i         : in    std_logic;                    -- error flag
     int_flag_i         : in    std_logic;                    -- interrupt flag
     start_dis_o        : out   std_logic;                    -- start disable, not used
     stop_dis_o         : out   std_logic;                    -- stop disable, not used
     -- Data interface with the ACAM on TDC mezzanine
     data_bus_io        : inout std_logic_vector(27 downto 0);
     address_o          : out   std_logic_vector(3 downto 0);
     cs_n_o             : out   std_logic;                    -- chip select for ACAM
     oe_n_o             : out   std_logic;                    -- output enable for ACAM
     rd_n_o             : out   std_logic;                    -- read  signal for ACAM
     wr_n_o             : out   std_logic;                    -- write signal for ACAM
     ef1_i              : in    std_logic;                    -- empty flag iFIFO1
     ef2_i              : in    std_logic;                    -- empty flag iFIFO2

     -- Enable of input Logic on TDC mezzanine
     enable_inputs_o    : out   std_logic;                    -- enables all 5 inputs
     term_en_1_o        : out   std_logic;                    -- Ch.1 termination enable of 50 Ohm termination
     term_en_2_o        : out   std_logic;                    -- Ch.2 termination enable of 50 Ohm termination
     term_en_3_o        : out   std_logic;                    -- Ch.3 termination enable of 50 Ohm termination
     term_en_4_o        : out   std_logic;                    -- Ch.4 termination enable of 50 Ohm termination
     term_en_5_o        : out   std_logic;                    -- Ch.5 termination enable of 50 Ohm termination

     -- LEDs on TDC mezzanine
     tdc_led_status_o   : out   std_logic;                    -- amber led on front pannel, division of 125 MHz tdc_clk
     tdc_led_trig1_o    : out   std_logic;                    -- amber led on front pannel, Ch.1 enable
     tdc_led_trig2_o    : out   std_logic;                    -- amber led on front pannel, Ch.2 enable
     tdc_led_trig3_o    : out   std_logic;                    -- amber led on front pannel, Ch.3 enable
     tdc_led_trig4_o    : out   std_logic;                    -- amber led on front pannel, Ch.4 enable
     tdc_led_trig5_o    : out   std_logic;                    -- amber led on front pannel, Ch.5 enable

     -- Input Logic on TDC mezzanine (not used currently)
     tdc_in_fpga_1_i    : in    std_logic;                    -- Ch.1 for ACAM, also received by FPGA
     tdc_in_fpga_2_i    : in    std_logic;                    -- Ch.2 for ACAM, also received by FPGA
     tdc_in_fpga_3_i    : in    std_logic;                    -- Ch.3 for ACAM, also received by FPGA
     tdc_in_fpga_4_i    : in    std_logic;                    -- Ch.4 for ACAM, also received by FPGA
     tdc_in_fpga_5_i    : in    std_logic;                    -- Ch.5 for ACAM, also received by FPGA

     -- I2C EEPROM interface on TDC mezzanine
     mezz_sys_scl_b     : inout std_logic := '1';             -- Mezzanine system EEPROM I2C clock
     mezz_sys_sda_b     : inout std_logic := '1';             -- Mezzanine system EEPROM I2C data

     -- 1-wire interface on TDC mezzanine
     mezz_one_wire_b    : inout std_logic;

     -- font panel leds
     led_red   : out std_logic;
     led_green : out std_logic;

     -- Carrier other signals
     pcb_ver_i          : in    std_logic_vector(3 downto 0); -- PCB version
     prsnt_m2c_n_i      : in    std_logic);                   -- Mezzanine presence (active low)

end spec_top_fmc_tdc;

--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of spec_top_fmc_tdc is

---------------------------------------------------------------------------------------------------
--                                         SDB CONSTANTS                                         --
---------------------------------------------------------------------------------------------------
  -- Note: All address in sdb and crossbar are BYTE addresses!

  -- Master ports on the wishbone crossbar
  constant c_NUM_WB_MASTERS       : integer := 5;
  constant c_WB_SLAVE_SPEC_ONEWIRE: integer := 0;  -- Carrier onewire interface
  constant c_WB_SLAVE_SPEC_INFO   : integer := 1;  -- Info on SPEC control and status registers
  constant c_WB_SLAVE_VIC         : integer := 2;  -- Interrupt controller
  constant c_WB_SLAVE_TDC         : integer := 3;  -- TDC core configuration
  constant c_SLAVE_WRCORE         : integer := 4;  -- White Rabbit PTP core

  -- SDB header address
  constant c_SDB_ADDRESS          : t_wishbone_address := x"00000000";

  -- Slave port on the wishbone crossbar
  constant c_NUM_WB_SLAVES        : integer := 1;
  constant c_MASTER_GENNUM        : integer := 0;

  constant c_FMC_TDC_SDB_BRIDGE   : t_sdb_bridge := f_xwb_bridge_manual_sdb(x"0001FFFF", x"00000000");
  constant c_WRCORE_BRIDGE_SDB    : t_sdb_bridge := f_xwb_bridge_manual_sdb(x"0003ffff", x"00000000");

  constant c_INTERCONNECT_LAYOUT  : t_sdb_record_array(6 downto 0) :=
    (0 => f_sdb_embed_device       (c_ONEWIRE_SDB_DEVICE,   x"00010000"),
     1 => f_sdb_embed_device       (c_SPEC_INFO_SDB_DEVICE, x"00020000"),
     2 => f_sdb_embed_device       (c_xwb_vic_sdb,          x"00030000"), -- c_xwb_vic_sdb described in the wishbone_pkg
     3 => f_sdb_embed_bridge       (c_FMC_TDC_SDB_BRIDGE,   x"00040000"),
     4 => f_sdb_embed_bridge       (c_WRCORE_BRIDGE_SDB,    x"00080000"),
     5 => f_sdb_embed_repo_url     (c_sdb_repo_url),
     6 => f_sdb_embed_synthesis    (c_sdb_synthesis_info));


---------------------------------------------------------------------------------------------------
--                                         VIC CONSTANT                                          --
---------------------------------------------------------------------------------------------------
  constant c_VIC_VECTOR_TABLE : t_wishbone_address_array(0 to 0) :=
    (0 => x"00052000");


---------------------------------------------------------------------------------------------------
--                                            Signals                                            --
---------------------------------------------------------------------------------------------------
  -- WRabbit clocks
  signal pllout_clk_sys, pllout_clk_dmtd                 : std_logic;
  signal pllout_clk_fb_pllref, pllout_clk_fb_dmtd        : std_logic;
  signal clk_125m_pllref, clk_125m_gtp                   : std_logic;
  signal clk_dmtd                                        : std_logic;
  attribute buffer_type                                  : string;  --" {bufgdll | ibufg | bufgp | ibuf | bufr | none}";
  attribute buffer_type of clk_125m_pllref               : signal is "BUFG";
  -- TDC core clocks and resets
  signal clk_20m_vcxo, clk_20m_vcxo_buf                  : std_logic;
  signal clk_62m5_sys, clk_125m_mezz                     : std_logic;
  signal rst_125m_mezz_n, rst_125m_mezz                  : std_logic;
  signal acam_refclk_r_edge_p                            : std_logic;
  signal rst_sys, rst_sys_n                              : std_logic;
  -- DAC configuration through PCIe/VME
  signal send_dac_word_p                                 : std_logic;
  signal dac_word                                        : std_logic_vector(23 downto 0);
  -- WISHBONE from crossbar master port
  signal cnx_master_out                                  : t_wishbone_master_out_array(c_NUM_WB_MASTERS-1 downto 0);
  signal cnx_master_in                                   : t_wishbone_master_in_array(c_NUM_WB_MASTERS-1 downto 0);
  -- WISHBONE to crossbar slave port
  signal cnx_slave_out                                   : t_wishbone_slave_out_array(c_NUM_WB_SLAVES-1 downto 0);
  signal cnx_slave_in                                    : t_wishbone_slave_in_array(c_NUM_WB_SLAVES-1 downto 0);
  signal tdc_slave_in                                    : t_wishbone_slave_in;
  signal tdc_slave_out                                   : t_wishbone_slave_out;
  signal gn_wb_adr                                       : std_logic_vector(31 downto 0);
  -- Carrier CSR info
  signal gn4124_status                                   : std_logic_vector(31 downto 0);
  -- Carrier 1-wire
  signal carrier_owr_en, carrier_owr_i                   : std_logic_vector(c_FMC_ONE_WIRE_NB - 1 downto 0);
  -- VIC
  signal fmc_eic_irq, irq_to_gn4124                      : std_logic;
  signal fmc_eic_irq_synch                               : std_logic_vector (1 downto 0);
  -- WRabbit time
  signal tm_link_up, tm_time_valid, tm_dac_wr_p          : std_logic;
  signal tm_utc                                          : std_logic_vector(39 downto 0);
  signal tm_cycles                                       : std_logic_vector(27 downto 0);
  signal tm_dac_value, tm_dac_value_reg                  : std_logic_vector(23 downto 0);
  signal tm_clk_aux_lock_en, tm_clk_aux_locked           : std_logic;
  -- WRabbit PHY
  signal phy_tx_data, phy_rx_data                        : std_logic_vector(7 downto 0);
  signal phy_tx_k, phy_tx_disparity, phy_rx_k            : std_logic;
  signal phy_tx_enc_err, phy_rx_rbclk                    : std_logic;
  signal phy_rx_enc_err, phy_rst, phy_loopen             : std_logic;
  signal phy_rx_bitslide                                 : std_logic_vector(3 downto 0);
  -- DAC configuration through WRabbit
  signal dac_hpll_load_p1, dac_dpll_load_p1              : std_logic;
  signal dac_hpll_data, dac_dpll_data                    : std_logic_vector(15 downto 0);
  -- EEPROM on mezzanine
  signal wrc_scl_out, wrc_scl_in, wrc_sda_out, wrc_sda_in: std_logic;
  signal tdc_scl_out, tdc_scl_in, tdc_sda_out, tdc_sda_in: std_logic;
  signal tdc_scl_oen, tdc_sda_oen                        : std_logic;
  -- SFP EEPROM on mezzanine  
  signal sfp_scl_out, sfp_scl_in, sfp_sda_out, sfp_sda_in: std_logic;
  -- Carrier 1-Wire
  signal wrc_owr_en, wrc_owr_in                          : std_logic_vector(1 downto 0);
  -- aux
  signal pll_sclk, pll_sdi, pll_dac_sync                 : std_logic;



--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

---------------------------------------------------------------------------------------------------
--                                     62.5 MHz system clock                                     --
---------------------------------------------------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cmp_clk_vcxo_ibuf : IBUFG
  port map
    (O => clk_20m_vcxo_buf,
     I => clk_20m_vcxo_i);

  cmp_clk_vcxo_gbuf : BUFG
  port map
    (O => clk_20m_vcxo,
     I => clk_20m_vcxo_buf);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cmp_sys_clk_pll : PLL_BASE
  generic map
    (BANDWIDTH          => "OPTIMIZED",
     CLK_FEEDBACK       => "CLKFBOUT",
     COMPENSATION       => "INTERNAL",
     DIVCLK_DIVIDE      => 1,
     CLKFBOUT_MULT      => 50,
     CLKFBOUT_PHASE     => 0.000,
     CLKOUT0_DIVIDE     => 16,         -- 62.5 MHz
     CLKOUT0_PHASE      => 0.000,
     CLKOUT0_DUTY_CYCLE => 0.500,
     CLKOUT1_DIVIDE     => 16,         -- not used
     CLKOUT1_PHASE      => 0.000,
     CLKOUT1_DUTY_CYCLE => 0.500,
     CLKOUT2_DIVIDE     => 16,
     CLKOUT2_PHASE      => 0.000,
     CLKOUT2_DUTY_CYCLE => 0.500,
     CLKIN_PERIOD       => 50.0,
     REF_JITTER         => 0.016)
  port map
    (CLKFBOUT           => pllout_clk_fb_pllref,
     CLKOUT0            => pllout_clk_sys,
     CLKOUT1            => open,
     CLKOUT2            => open,
     CLKOUT3            => open,
     CLKOUT4            => open,
     CLKOUT5            => open,
     LOCKED             => open,
     RST                => '0',
     CLKFBIN            => pllout_clk_fb_pllref,
     CLKIN              => clk_20m_vcxo);
    
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cmp_clk_sys_buf : BUFG
  port map
    (O => clk_62m5_sys,
     I => pllout_clk_sys);	


---------------------------------------------------------------------------------------------------
--                                   Reset for 62M5 clk domain                                   --
---------------------------------------------------------------------------------------------------

  U_Reset_Generator : spec_reset_gen
  port map
    (clk_sys_i        => clk_62m5_sys,
     rst_pcie_n_a_i   => rst_n_a_i,
     rst_button_n_a_i => button1_i,
     rst_n_o          => rst_sys_n);
  --  --  --  --  --  --  --  --  --  --
     rst_sys          <= not rst_sys_n;


---------------------------------------------------------------------------------------------------
--                               125 MHz clk and Reset for TDC core                              --
---------------------------------------------------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cmp_tdc_clks_rsts_mgment : clks_rsts_manager
  generic map
    (nb_of_reg              => 68)
  port map
    (clk_sys_i              => clk_62m5_sys,
     acam_refclk_p_i        => acam_refclk_p_i,
     acam_refclk_n_i        => acam_refclk_n_i,
     tdc_125m_clk_p_i       => tdc_clk_125m_p_i,
     tdc_125m_clk_n_i       => tdc_clk_125m_n_i,
     rst_n_i                => rst_n_a_i,
     pll_sdo_i              => pll_sdo_i,
     pll_status_i           => pll_status_i,
     send_dac_word_p_i      => send_dac_word_p,
     dac_word_i             => dac_word,
     acam_refclk_r_edge_p_o => acam_refclk_r_edge_p,
     wrabbit_dac_value_i    => tm_dac_value,
     wrabbit_dac_wr_p_i     => tm_dac_wr_p,
     internal_rst_o         => rst_125m_mezz,
     pll_cs_n_o             => pll_cs_o,
     pll_dac_sync_n_o       => pll_dac_sync,
     pll_sdi_o              => pll_sdi,
     pll_sclk_o             => pll_sclk,
     tdc_125m_clk_o         => clk_125m_mezz,
     pll_status_o           => open);
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  rst_125m_mezz_n           <= not rst_125m_mezz;
  pll_dac_sync_o            <= pll_dac_sync;
  pll_sdi_o                 <= pll_sdi;
  pll_sclk_o                <= pll_sclk;

---------------------------------------------------------------------------------------------------
--                                      62.5 MHz DMTD clock                                      --
---------------------------------------------------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cmp_dmtd_clk_pll : PLL_BASE
  generic map
    (BANDWIDTH          => "OPTIMIZED",
     CLK_FEEDBACK       => "CLKFBOUT",
     COMPENSATION       => "INTERNAL",
     DIVCLK_DIVIDE      => 1,
     CLKFBOUT_MULT      => 50,
     CLKFBOUT_PHASE     => 0.000,
     CLKOUT0_DIVIDE     => 16,         -- 62.5 MHz
     CLKOUT0_PHASE      => 0.000,
     CLKOUT0_DUTY_CYCLE => 0.500,
     CLKOUT1_DIVIDE     => 16,         -- not used
     CLKOUT1_PHASE      => 0.000,
     CLKOUT1_DUTY_CYCLE => 0.500,
     CLKOUT2_DIVIDE     => 8,
     CLKOUT2_PHASE      => 0.000,
     CLKOUT2_DUTY_CYCLE => 0.500,
     CLKIN_PERIOD       => 50.0,
     REF_JITTER         => 0.016)
  port map
    (CLKFBOUT           => pllout_clk_fb_dmtd,
     CLKOUT0            => pllout_clk_dmtd,
     CLKOUT1            => open,
     CLKOUT2            => open,
     CLKOUT3            => open,
     CLKOUT4            => open,
     CLKOUT5            => open,
     LOCKED             => open,
     RST                => '0',
     CLKFBIN            => pllout_clk_fb_dmtd,
     CLKIN              => clk_20m_vcxo_buf);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cmp_clk_dmtd_buf : BUFG
  port map
    (O => clk_dmtd,
     I => pllout_clk_dmtd);


---------------------------------------------------------------------------------------------------
--                               125 MHz clk for White Rabbit core                               --
---------------------------------------------------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  U_Buf_CLK_PLL : IBUFGDS
  generic map
    (DIFF_TERM    => true,
     IBUF_LOW_PWR => true)       -- Low power (TRUE) vs. performance (FALSE) setting for referenced
  port map
    (O  => clk_125m_pllref,      -- Buffer output
     I  => clk_125m_pllref_p_i,  -- Diff_p buffer input (connect directly to top-level port)
     IB => clk_125m_pllref_n_i); -- Diff_n buffer input (connect directly to top-level port)

     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  U_Buf_CLK_GTP : IBUFDS
  generic map
    (DIFF_TERM   => true,
     IBUF_LOW_PWR => false)
  port map
    (O  => clk_125m_gtp,
     I  => clk_125m_gtp_p_i,
     IB => clk_125m_gtp_n_i);


---------------------------------------------------------------------------------------------------
--                                  White Rabbit Core + PHY                                      --
---------------------------------------------------------------------------------------------------

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  U_WR_CORE : xwr_core
  generic map
    (g_simulation                => 0,
     g_phys_uart                 => true,
     g_virtual_uart              => true,
     g_with_external_clock_input => false,
     g_aux_clks                  => 1,
     g_ep_rxbuf_size             => 1024,
     g_dpram_initf               => "wrc.ram",
     g_dpram_size                => 90112/4,
     g_interface_mode            => PIPELINED,
     g_address_granularity       => BYTE,
     g_softpll_enable_debugger   => false)
  port map
    (clk_sys_i                   => clk_62m5_sys,
     clk_dmtd_i                  => clk_dmtd,
     clk_ref_i                   => clk_125m_pllref,
     clk_aux_i(0)                => clk_125m_mezz,
     rst_n_i                     => rst_sys_n,
     -- DAC
     dac_hpll_load_p1_o          => dac_hpll_load_p1,
     dac_hpll_data_o             => dac_hpll_data,
     dac_dpll_load_p1_o          => dac_dpll_load_p1,
     dac_dpll_data_o             => dac_dpll_data,
     -- PHY
     phy_ref_clk_i               => clk_125m_pllref,
     phy_tx_data_o               => phy_tx_data,
     phy_tx_k_o                  => phy_tx_k,
     phy_tx_disparity_i          => phy_tx_disparity,
     phy_tx_enc_err_i            => phy_tx_enc_err,
     phy_rx_data_i               => phy_rx_data,
     phy_rx_rbclk_i              => phy_rx_rbclk,
     phy_rx_k_i                  => phy_rx_k,
     phy_rx_enc_err_i            => phy_rx_enc_err,
     phy_rx_bitslide_i           => phy_rx_bitslide,
     phy_rst_o                   => phy_rst,
     phy_loopen_o                => phy_loopen,
     -- SPEC LEDs
     led_act_o                   => LED_RED,
     led_link_o                  => LED_GREEN,
     -- SFP
     scl_o                       => wrc_scl_out,
     scl_i                       => wrc_scl_in,
     sda_o                       => wrc_sda_out,
     sda_i                       => wrc_sda_in,
     sfp_scl_o                   => sfp_scl_out,
     sfp_scl_i                   => sfp_scl_in,
     sfp_sda_o                   => sfp_sda_out,
     sfp_sda_i                   => sfp_sda_in,
     sfp_det_i                   => sfp_mod_def0_b,
     uart_rxd_i                  => uart_rxd_i,
     uart_txd_o                  => uart_txd_o,
     -- 1-wire
     owr_en_o                    => wrc_owr_en,
     owr_i                       => wrc_owr_in,
     -- WISHBONE
     slave_i                     => cnx_master_out(c_SLAVE_WRCORE),
     slave_o                     => cnx_master_in(c_SLAVE_WRCORE),
     -- Timimg info for TDC core
     tm_link_up_o                => tm_link_up,
     tm_dac_value_o              => tm_dac_value,
     tm_dac_wr_o(0)              => tm_dac_wr_p,
     tm_clk_aux_lock_en_i(0)     => tm_clk_aux_lock_en,
     tm_clk_aux_locked_o(0)      => tm_clk_aux_locked,
     tm_time_valid_o             => tm_time_valid,
     tm_tai_o                    => tm_utc,
     tm_cycles_o                 => tm_cycles,
     -- not used
     btn1_i                      => '1',
     btn2_i                      => '1',
     pps_p_o                     => open,
     -- aux reset
     rst_aux_n_o                 => open);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  U_GTP : wr_gtp_phy_spartan6
  generic map
    (g_simulation       => 0,
     g_enable_ch0       => 0,
     g_enable_ch1       => 1)
  port map
    (gtp_clk_i          => clk_125m_gtp,
     ch0_ref_clk_i      => clk_125m_pllref,
     ch0_tx_data_i      => x"00",
     ch0_tx_k_i         => '0',
     ch0_tx_disparity_o => open,
     ch0_tx_enc_err_o   => open,
     ch0_rx_rbclk_o     => open,
     ch0_rx_data_o      => open,
     ch0_rx_k_o         => open,
     ch0_rx_enc_err_o   => open,
     ch0_rx_bitslide_o  => open,
     ch0_rst_i          => '1',
     ch0_loopen_i       => '0',
     ch1_ref_clk_i      => clk_125m_pllref,
     ch1_tx_data_i      => phy_tx_data,
     ch1_tx_k_i         => phy_tx_k,
     ch1_tx_disparity_o => phy_tx_disparity,
     ch1_tx_enc_err_o   => phy_tx_enc_err,
     ch1_rx_data_o      => phy_rx_data,
     ch1_rx_rbclk_o     => phy_rx_rbclk,
     ch1_rx_k_o         => phy_rx_k,
     ch1_rx_enc_err_o   => phy_rx_enc_err,
     ch1_rx_bitslide_o  => phy_rx_bitslide,
     ch1_rst_i          => phy_rst,
     ch1_loopen_i       => '0', -- phy_loopen,
     pad_txn0_o         => open,
     pad_txp0_o         => open,
     pad_rxn0_i         => '0',
     pad_rxp0_i         => '0',
     pad_txn1_o         => sfp_txn_o,
     pad_txp1_o         => sfp_txp_o,
     pad_rxn1_i         => sfp_rxn_i,
     pad_rxp1_i         => sfp_rxp_i);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  U_DAC_ARB : spec_serial_dac_arb
  generic map
    (g_invert_sclk    => false,
     g_num_extra_bits => 8)
  port map
    (clk_i            => clk_62m5_sys,
     rst_n_i          => rst_sys_n,
     val1_i           => dac_dpll_data,
     load1_i          => dac_dpll_load_p1,
     val2_i           => dac_hpll_data,
     load2_i          => dac_hpll_load_p1,
     dac_cs_n_o(0)    => dac_cs1_n_o,
     dac_cs_n_o(1)    => dac_cs2_n_o,
     -- dac_clr_n_o   => open,
     dac_sclk_o       => dac_sclk_o,
     dac_din_o        => dac_din_o);
     --  --  --  --  --  --
     sfp_tx_disable_o <= '0';
     -- dac_clr_n_o   <= '1';

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
     -- Tristates for Carrier EEPROM
  mezz_sys_scl_b      <= '0' when (wrc_scl_out = '0') else 'Z';--tdc_scl_out when (tdc_scl_oen = '0') else '0' when (wrc_scl_out = '0') else 'Z';
  mezz_sys_sda_b      <= '0' when (wrc_sda_out = '0') else 'Z';--tdc_sda_out when (tdc_sda_oen = '0') else '0' when (wrc_sda_out = '0') else 'Z';
  wrc_scl_in          <= mezz_sys_scl_b;
  wrc_sda_in          <= mezz_sys_sda_b;
  tdc_scl_in          <= mezz_sys_scl_b;
  tdc_sda_in          <= mezz_sys_sda_b;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Tristates for SFP EEPROM
  sfp_mod_def1_b      <= '0' when sfp_scl_out = '0' else 'Z';
  sfp_mod_def2_b      <= '0' when sfp_sda_out = '0' else 'Z';
  sfp_scl_in          <= sfp_mod_def1_b;
  sfp_sda_in          <= sfp_mod_def2_b;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  carrier_onewire_b   <= '0' when wrc_owr_en(0) = '1' else 'Z';
  wrc_owr_in(0)       <= carrier_onewire_b;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --


---------------------------------------------------------------------------------------------------
--                                     CSR WISHBONE CROSSBAR                                     --
---------------------------------------------------------------------------------------------------
--   0x00000 -> SDB
--   0x10000 -> Carrier 1-wire master
--   0x20000 -> Carrier CSR information
--   0x30000 -> Vector Interrupt Controller
--   0x40000 -> TDC mezzanine SDB
--     0x10000 -> TDC core configuration (including ACAM regs)
--     0x11000 -> TDC Mezzanine 1-wire master
--     0x12000 -> TDC Mezzanine Embedded Interrupt Controller
--     0x13000 -> TDC Mezzanine I2C master
--     0x14000 -> TDC core timestamps retrieval from memory
  cmp_sdb_crossbar : xwb_sdb_crossbar
  generic map
    (g_num_masters => c_NUM_WB_SLAVES,
     g_num_slaves  => c_NUM_WB_MASTERS,
     g_registered  => true,
     g_wraparound  => true,
     g_layout      => c_INTERCONNECT_LAYOUT,
     g_sdb_addr    => c_SDB_ADDRESS)
  port map
    (clk_sys_i     => clk_62m5_sys,
     rst_n_i       => rst_sys_n,
     slave_i       => cnx_slave_in,
     slave_o       => cnx_slave_out,
     master_i      => cnx_master_in,
     master_o      => cnx_master_out);


---------------------------------------------------------------------------------------------------
--                                           GN4124 CORE                                         --
---------------------------------------------------------------------------------------------------
  cmp_gn4124_core: gn4124_core
  port map
    (rst_n_a_i       => rst_n_a_i,
     status_o        => gn4124_status,
    -- P2L Direction Source Sync DDR related signals
     p2l_clk_p_i     => p2l_clk_p_i,
     p2l_clk_n_i     => p2l_clk_n_i,
     p2l_data_i      => p2l_data_i,
     p2l_dframe_i    => p2l_dframe_i,
     p2l_valid_i     => p2l_valid_i,
    -- P2L Control
     p2l_rdy_o       => p2l_rdy_o,
     p_wr_req_i      => p_wr_req_i,
     p_wr_rdy_o      => p_wr_rdy_o,
     rx_error_o      => rx_error_o,
    -- L2P Direction Source Sync DDR related signals
     l2p_clk_p_o     => l2p_clk_p_o,
     l2p_clk_n_o     => l2p_clk_n_o,
     l2p_data_o      => l2p_data_o ,
     l2p_dframe_o    => l2p_dframe_o,
     l2p_valid_o     => l2p_valid_o,
     l2p_edb_o       => l2p_edb_o,
    -- L2P Control
     l2p_rdy_i       => l2p_rdy_i,
     l_wr_rdy_i      => l_wr_rdy_i,
     p_rd_d_rdy_i    => p_rd_d_rdy_i,
     tx_error_i      => tx_error_i,
     vc_rdy_i        => vc_rdy_i,
    -- Interrupt interface
     dma_irq_o       => open,
     irq_p_i         => irq_to_gn4124,
     irq_p_o         => irq_p_o,
    -- CSR WISHBONE interface (master pipelined)
     csr_clk_i       => clk_62m5_sys,
     csr_adr_o       => gn_wb_adr,
     csr_dat_o       => cnx_slave_in(c_MASTER_GENNUM).dat,
     csr_sel_o       => cnx_slave_in(c_MASTER_GENNUM).sel,
     csr_stb_o       => cnx_slave_in(c_MASTER_GENNUM).stb,
     csr_we_o        => cnx_slave_in(c_MASTER_GENNUM).we,
     csr_cyc_o       => cnx_slave_in(c_MASTER_GENNUM).cyc,
     csr_dat_i       => cnx_slave_out(c_MASTER_GENNUM).dat,
     csr_ack_i       => cnx_slave_out(c_MASTER_GENNUM).ack,
     csr_stall_i     => cnx_slave_out(c_MASTER_GENNUM).stall,
    -- DMA: not used
     dma_clk_i       => clk_62m5_sys,
     dma_adr_o       => open,
     dma_cyc_o       => open,
     dma_dat_o       => open,
     dma_sel_o       => open,
     dma_stb_o       => open,
     dma_we_o        => open,
     dma_ack_i       => '1',
     dma_dat_i       => (others => '0'),
     dma_stall_i     => '0',
     dma_reg_clk_i   => clk_62m5_sys,
     dma_reg_adr_i   => (others => '0'),
     dma_reg_dat_i   => (others => '0'),
     dma_reg_sel_i   => (others => '0'),
     dma_reg_stb_i   => '0',
     dma_reg_we_i    => '0',
     dma_reg_cyc_i   => '0',
     dma_reg_dat_o   => open,
     dma_reg_ack_o   => open,
     dma_reg_stall_o => open);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Convert 32-bit word address into byte address for crossbar
  cnx_slave_in(c_MASTER_GENNUM).adr <= gn_wb_adr(29 downto 0) & "00";


---------------------------------------------------------------------------------------------------
--                                            TDC BOARD                                          --
---------------------------------------------------------------------------------------------------
  cmp_tdc_mezz : fmc_tdc_mezzanine
  generic map
    (g_span                    => g_span,
     g_width                   => g_width,
     values_for_simul          => FALSE)
  port map
    -- 62M5 clk and reset
    (clk_sys_i                 => clk_62m5_sys,
     rst_sys_n_i               => rst_sys_n,
    -- 125M clk and reset
     clk_ref_0_i               => clk_125m_mezz,
     rst_ref_0_i               => rst_125m_mezz,
    -- Configuration of the DAC on the TDC mezzanine, non White Rabbit
     acam_refclk_r_edge_p_i    => acam_refclk_r_edge_p,
     send_dac_word_p_o         => send_dac_word_p,
     dac_word_o                => dac_word,
    -- ACAM interface
     start_from_fpga_o         => start_from_fpga_o,
     err_flag_i                => err_flag_i,
     int_flag_i                => int_flag_i,
     start_dis_o               => start_dis_o,
     stop_dis_o                => stop_dis_o,
     data_bus_io               => data_bus_io,
     address_o                 => address_o,
     cs_n_o                    => cs_n_o,
     oe_n_o                    => oe_n_o,
     rd_n_o                    => rd_n_o,
     wr_n_o                    => wr_n_o,
     ef1_i                     => ef1_i,
     ef2_i                     => ef2_i,
    -- Input channels enable
     enable_inputs_o           => enable_inputs_o,
     term_en_1_o               => term_en_1_o,
     term_en_2_o               => term_en_2_o,
     term_en_3_o               => term_en_3_o,
     term_en_4_o               => term_en_4_o,
     term_en_5_o               => term_en_5_o,
    -- LEDs on TDC mezzanine
     tdc_led_status_o          => tdc_led_status_o,
     tdc_led_trig1_o           => tdc_led_trig1_o,
     tdc_led_trig2_o           => tdc_led_trig2_o,
     tdc_led_trig3_o           => tdc_led_trig3_o,
     tdc_led_trig4_o           => tdc_led_trig4_o,
     tdc_led_trig5_o           => tdc_led_trig5_o,
    -- Input channels to FPGA (not used)
     tdc_in_fpga_1_i           => tdc_in_fpga_1_i,
     tdc_in_fpga_2_i           => tdc_in_fpga_2_i,
     tdc_in_fpga_3_i           => tdc_in_fpga_3_i,
     tdc_in_fpga_4_i           => tdc_in_fpga_4_i,
     tdc_in_fpga_5_i           => tdc_in_fpga_5_i,
    -- WISHBONE interface with the GN4124 core
     wb_tdc_csr_adr_i          => tdc_slave_in.adr,
     wb_tdc_csr_dat_i          => tdc_slave_in.dat,
     wb_tdc_csr_stb_i          => tdc_slave_in.stb,
     wb_tdc_csr_we_i           => tdc_slave_in.we,
     wb_tdc_csr_cyc_i          => tdc_slave_in.cyc,
     wb_tdc_csr_sel_i          => tdc_slave_in.sel,
     wb_tdc_csr_dat_o          => tdc_slave_out.dat,
     wb_tdc_csr_ack_o          => tdc_slave_out.ack,
     wb_tdc_csr_stall_o        => tdc_slave_out.stall,
    -- White Rabbit
     wrabbit_link_up_i         => tm_link_up,
     wrabbit_time_valid_i      => tm_time_valid,
     wrabbit_cycles_i          => tm_cycles,
     wrabbit_utc_i             => tm_utc(31 downto 0),
     wrabbit_utc_p_o           => open, -- for debug
     wrabbit_clk_aux_lock_en_o => tm_clk_aux_lock_en,
     wrabbit_clk_aux_locked_i  => tm_clk_aux_locked,
     wrabbit_clk_dmtd_locked_i => '1', -- FIXME: fan out real signal from the WRCore
     wrabbit_dac_value_i       => tm_dac_value_reg,
     wrabbit_dac_wr_p_i        => tm_dac_wr_p,
    -- Interrupt line from EIC
     wb_irq_o                  => fmc_eic_irq,
    -- EEPROM I2C on TDC mezzanine
     i2c_scl_oen_o             => tdc_scl_oen,
     i2c_scl_i                 => tdc_scl_in,
     i2c_sda_oen_o             => tdc_sda_oen,
     i2c_sda_i                 => tdc_sda_in,
     i2c_scl_o                 => tdc_scl_out,
     i2c_sda_o                 => tdc_sda_out,
    -- 1-Wire on TDC mezzanine
     one_wire_b                => mezz_one_wire_b);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Domains crossing: clk_125m_mezz <-> clk_62m5_sys
  cmp_tdc_clk_crossing : xwb_clock_crossing
  port map
    (slave_clk_i    => clk_62m5_sys,  -- Slave control port: GNUM interface at 62.5 MHz
     slave_rst_n_i  => rst_sys_n,
     slave_i        => cnx_master_out(c_WB_SLAVE_TDC),
     slave_o        => cnx_master_in(c_WB_SLAVE_TDC),
     master_clk_i   => clk_125m_mezz, -- Master reader port: TDC core at 125 MHz
     master_rst_n_i => rst_125m_mezz_n,
     master_i       => tdc_slave_out,
     master_o       => tdc_slave_in);


---------------------------------------------------------------------------------------------------
--                                              VIC                                              --
---------------------------------------------------------------------------------------------------
  cmp_vic : xwb_vic
  generic map
    (g_interface_mode      => PIPELINED,
     g_address_granularity => BYTE,
     g_num_interrupts      => 1,
     g_init_vectors        => c_VIC_VECTOR_TABLE)
  port map
    (clk_sys_i    => clk_62m5_sys,
     rst_n_i      => rst_sys_n,
     slave_i      => cnx_master_out(c_WB_SLAVE_VIC),
     slave_o      => cnx_master_in(c_WB_SLAVE_VIC),
     irqs_i(0)    => fmc_eic_irq_synch(1),
     irq_master_o => irq_to_gn4124);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Domains crossing: synchronization of the wb_ird_o from 125MHz to 62.5MHz
  irq_pulse_synchronizer: process (clk_62m5_sys)
  begin
    if rising_edge (clk_62m5_sys) then
      if rst_sys_n = '0' then
        fmc_eic_irq_synch <= (others => '0');
      else
        fmc_eic_irq_synch <= fmc_eic_irq_synch(0) & fmc_eic_irq;
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                    Carrier 1-wire MASTER DS18B20 (thermometer + unique ID)                    --
---------------------------------------------------------------------------------------------------
  -- cmp_carrier_onewire : xwb_onewire_master
  -- generic map
    -- (g_interface_mode      => CLASSIC,
     -- g_address_granularity => BYTE,
     -- g_num_ports           => 1,
     -- g_ow_btp_normal       => "5.0",
     -- g_ow_btp_overdrive    => "1.0")
  -- port map
    -- (clk_sys_i   => clk_62m5_sys,
     -- rst_n_i     => rst_sys_n,
     -- slave_i     => cnx_master_out(c_WB_SLAVE_SPEC_ONEWIRE),
     -- slave_o     => cnx_master_in(c_WB_SLAVE_SPEC_ONEWIRE),
     -- desc_o      => open,
     -- owr_pwren_o => open,
     -- owr_en_o    => carrier_owr_en,
     -- owr_i       => carrier_owr_i);

   --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- carrier_onewire_b  <= '0' when carrier_owr_en(0) = '1' else 'Z';
  -- carrier_owr_i(0)   <= carrier_onewire_b;


---------------------------------------------------------------------------------------------------
--                                    Carrier CSR information                                    --
---------------------------------------------------------------------------------------------------
-- Information on carrier type, mezzanine presence, pcb version

  cmp_carrier_info : carrier_info
  port map
    (rst_n_i                           => rst_sys_n,
     clk_sys_i                         => clk_62m5_sys,
     wb_adr_i                          => cnx_master_out(c_WB_SLAVE_SPEC_INFO).adr(3 downto 2),
     wb_dat_i                          => cnx_master_out(c_WB_SLAVE_SPEC_INFO).dat,
     wb_dat_o                          => cnx_master_in(c_WB_SLAVE_SPEC_INFO).dat,
     wb_cyc_i                          => cnx_master_out(c_WB_SLAVE_SPEC_INFO).cyc,
     wb_sel_i                          => cnx_master_out(c_WB_SLAVE_SPEC_INFO).sel,
     wb_stb_i                          => cnx_master_out(c_WB_SLAVE_SPEC_INFO).stb,
     wb_we_i                           => cnx_master_out(c_WB_SLAVE_SPEC_INFO).we,
     wb_ack_o                          => cnx_master_in(c_WB_SLAVE_SPEC_INFO).ack,
     wb_stall_o                        => cnx_master_in(c_WB_SLAVE_SPEC_INFO).stall,
     carrier_info_carrier_pcb_rev_i    => pcb_ver_i,
     carrier_info_carrier_reserved_i   => (others => '0'),
     carrier_info_carrier_type_i       => c_CARRIER_TYPE,
     carrier_info_stat_fmc_pres_i      => prsnt_m2c_n_i,
     carrier_info_stat_p2l_pll_lck_i   => gn4124_status(0),
     carrier_info_stat_sys_pll_lck_i   => '0',
     carrier_info_stat_ddr3_cal_done_i => '0',
     carrier_info_stat_reserved_i      => (others => '0'),
     carrier_info_ctrl_led_green_o     => open,
     carrier_info_ctrl_led_red_o       => open,
     carrier_info_ctrl_dac_clr_n_o     => open,
     carrier_info_ctrl_reserved_o      => open,
     carrier_info_rst_fmc0_n_o         => open,
     carrier_info_rst_fmc0_n_i         => '1',
     carrier_info_rst_fmc0_n_load_o    => open,
     carrier_info_rst_reserved_o       => open);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Unused wishbone signals
  cnx_master_in(c_WB_SLAVE_SPEC_INFO).err   <= '0';
  cnx_master_in(c_WB_SLAVE_SPEC_INFO).rty   <= '0';
  cnx_master_in(c_WB_SLAVE_SPEC_INFO).int   <= '0';


end rtl;
----------------------------------------------------------------------------------------------------
--  architecture ends
----------------------------------------------------------------------------------------------------