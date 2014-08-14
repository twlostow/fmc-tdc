--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                        fmc_tdc_mezzanine                                       |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         fmc_tdc_mezzanine.vhd                                                             |
--                                                                                                |
-- Description  The unit combines                                                                 |
--                o the TDC core                                                                  |
--                o the wrabbit_sync unit that is managing the White Rabbit synchronization  and  |
--                  control signals                                                               |
--                o the I2C core for the communication with the TDC board EEPROM                  |
--                o the OneWire core for the communication with the TDC board UniqueID&Thermeter  |
--                o the Embedded Interrupt Controller core that concentrates several interrupt    |
--                  sources into one WISHBONE interrupt request line.                             |
--                                                                                                |
--              For the interconnection between the GN4124/VME core and the different cores (TDC, |
--              I2C, 1W, EIC, timestamps memory) the unit instantiates an SDB crossbar.           |
--                                                                                                |
--              Note that the TDC core uses word addressing, whereas the GN4124/VME cores use byte|
--              addressing                                                                        |
--                                   _______________________________                              |
--                                 |       FMC TDC mezzanine        |                             |
--                                 |                                |                             |
--                                 |     ________________           |                             |
--                                 | |--|  WRabbit_sync  |          |                             |
--                                 | |  |________________|          |                             |
--                                 | |   ________________    ___    |                             |
--                                 | |->|                |  |   |   |                             |
--                 ACAM chip <-->  |    |    TDC core    |  |   |   |   <-->                      |
--                                 | |--|________________|  | S |   |                             |
--                                 | |   ________________   |   |   |                             |
--                                 | |  |                |  |   |   |                             |
--               EEPROM chip <-->  | |  |    I2C core    |  |   |   |   <-->                      |
--                                 | |  |________________|  |   |   |                             |
--                                 | |   ________________   | D |   |          GN4124/VME core    |
--                                 | |  |                |  |   |   |                             |
--                   1W chip <-->  | |  |     1W core    |  |   |   |   <-->                      |
--                                 | |  |________________|  |   |   |                             |
--                                 | |   ________________   |   |   |                             |
--                                 | |  |                |  | B |   |                             |
--                                 | |->|       EIC      |  |   |   |   <-->                      |
--                                 |    |________________|  |___|   |                             |
--                                 |                                |                             |
--                                 |________________________________|                             |
--                                     ^                        ^                                 |
--                                     | 125 MHz            rst |                                 |
--                                   __|________________________|___                              |
--                                  |                               |                             |
--                   DAC chip <-->  |       clks_rsts_manager       |                             |
--                   PLL chip       |_______________________________|                             |
--                                                                                                |
--                         Figure 1: FMC TDC mezzanine architecture and                           |
--                          connection with the clks_rsts_manager unit                            |
--                                                                                                |
--                                                                                                |
--                                                                                                |
-- Authors      Gonzalo Penacoba  (Gonzalo.Penacoba@cern.ch)                                      |
--              Evangelia Gousiou (Evangelia.Gousiou@cern.ch)                                     |
-- Date         01/2014                                                                           |
-- Version      v2                                                                                |
-- Depends on                                                                                     |
--                                                                                                |
----------------                                                                                  |
-- Last changes                                                                                   |
--     07/2013  v1  EG  First version                                                             |
--     01/2014  v2  EG  Different output for the timestamp data                                   |
--     01/2014  v3  EG  Removed option for timestamps retrieval through DMA                       |
--     08/2014  v4  EG  Corrected missalignement between wrabbit_tai and wrabbit_tai_p (line 444) |
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
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tdc_core_pkg.all;
use work.gencores_pkg.all;
use work.wishbone_pkg.all;


--=================================================================================================
--                                Entity declaration for fmc_tdc_mezzanine
--=================================================================================================
entity fmc_tdc_mezzanine is
  generic
    (g_with_wrabbit_core       : boolean := FALSE;
     g_span                    : integer := 32;
     g_width                   : integer := 32;
     values_for_simul          : boolean := FALSE);
  port
    -- TDC core
    (-- Clock & reset 62M5
     clk_sys_i                 : in    std_logic; -- 62.5 MHz clock
     rst_sys_n_i               : in    std_logic; -- reset for 62.5 MHz logic
     -- Signals from the clks_rsts_manager unit
     clk_ref_0_i               : in    std_logic; -- 125 MHz clock
     rst_ref_0_i               : in    std_logic; -- reset for 125 MHz logic
     acam_refclk_r_edge_p_i    : in    std_logic;
     send_dac_word_p_o         : out   std_logic;
     dac_word_o                : out   std_logic_vector(23 downto 0);
     -- Interface with ACAM
     start_from_fpga_o         : out   std_logic;
     err_flag_i                : in    std_logic;
     int_flag_i                : in    std_logic;
     start_dis_o               : out   std_logic;
     stop_dis_o                : out   std_logic;
     data_bus_io               : inout std_logic_vector(27 downto 0);
     address_o                 : out   std_logic_vector(3 downto 0);
     cs_n_o                    : out   std_logic;
     oe_n_o                    : out   std_logic;
     rd_n_o                    : out   std_logic;
     wr_n_o                    : out   std_logic;
     ef1_i                     : in    std_logic;
     ef2_i                     : in    std_logic;
     -- Channels termination 
     enable_inputs_o           : out   std_logic;
     term_en_1_o               : out   std_logic;
     term_en_2_o               : out   std_logic;
     term_en_3_o               : out   std_logic;
     term_en_4_o               : out   std_logic;
     term_en_5_o               : out   std_logic;
     -- TDC board LEDs
     tdc_led_status_o          : out   std_logic;
     tdc_led_trig1_o           : out   std_logic;
     tdc_led_trig2_o           : out   std_logic;
     tdc_led_trig3_o           : out   std_logic;
     tdc_led_trig4_o           : out   std_logic;
     tdc_led_trig5_o           : out   std_logic;
     -- Input pulses arriving also to the FPGA, currently not treated
     tdc_in_fpga_1_i           : in    std_logic;
     tdc_in_fpga_2_i           : in    std_logic;
     tdc_in_fpga_3_i           : in    std_logic;
     tdc_in_fpga_4_i           : in    std_logic;
     tdc_in_fpga_5_i           : in    std_logic;
     -- White Rabbit core
     wrabbit_link_up_i         : in    std_logic;
     wrabbit_time_valid_i      : in    std_logic;
     wrabbit_cycles_i          : in    std_logic_vector(27 downto 0);
     wrabbit_utc_i             : in    std_logic_vector(31 downto 0);
     wrabbit_clk_aux_lock_en_o : out   std_logic;
     wrabbit_clk_aux_locked_i  : in    std_logic;
     wrabbit_clk_dmtd_locked_i : in    std_logic;
     wrabbit_dac_value_i       : in    std_logic_vector(23 downto 0);
     wrabbit_dac_wr_p_i        : in    std_logic;
     -- WISHBONE interface with the GN4124/VME_core
     -- for the core configuration | timestamps retrieval | core interrupts | 1Wire | I2C 
     wb_tdc_csr_adr_i          : in    std_logic_vector(31 downto 0);
     wb_tdc_csr_dat_i          : in    std_logic_vector(31 downto 0);
     wb_tdc_csr_cyc_i          : in    std_logic;
     wb_tdc_csr_sel_i          : in    std_logic_vector(3 downto 0);
     wb_tdc_csr_stb_i          : in    std_logic;
     wb_tdc_csr_we_i           : in    std_logic;
     wb_tdc_csr_dat_o          : out   std_logic_vector(31 downto 0);
     wb_tdc_csr_ack_o          : out   std_logic;
     wb_tdc_csr_stall_o        : out   std_logic;
     wb_irq_o                  : out   std_logic;
    -- I2C EEPROM interface
     i2c_scl_o                 : out   std_logic;
     i2c_scl_oen_o             : out   std_logic;
     i2c_scl_i                 : in    std_logic;
     i2c_sda_oen_o             : out   std_logic;
     i2c_sda_o                 : out   std_logic;
     i2c_sda_i                 : in    std_logic;
    -- 1-Wire interface
     onewire_b                 : inout std_logic;
     direct_timestamp_o : out std_logic_vector(127 downto 0);
     direct_timestamp_stb_o : out std_logic
);
end fmc_tdc_mezzanine;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of fmc_tdc_mezzanine is

---------------------------------------------------------------------------------------------------
--                                         SDB CONSTANTS                                         --
---------------------------------------------------------------------------------------------------
  -- Note: All address in sdb and crossbar are BYTE addresses!

  -- Master ports on the wishbone crossbar
  constant c_NUM_WB_MASTERS           : integer := 5;
  constant c_WB_SLAVE_TDC_ONEWIRE     : integer := 0;  -- TDC mezzanine board UnidueID&Thermometer 1-wire
  constant c_WB_SLAVE_TDC_CORE_CONFIG : integer := 1;  -- TDC core configuration registers
  constant c_WB_SLAVE_TDC_EIC         : integer := 2;  -- TDC interrupts
  constant c_WB_SLAVE_TDC_I2C         : integer := 3;  -- TDC mezzanine board system EEPROM I2C
  constant c_WB_SLAVE_TSTAMP_MEM      : integer := 4;  -- Access to TDC core memory for timestamps retrieval

  -- Slave port on the wishbone crossbar
  constant c_NUM_WB_SLAVES            : integer := 1;

  -- Wishbone master(s)
  constant c_WB_MASTER                : integer := 0;

  -- sdb header address
  constant c_SDB_ADDRESS              : t_wishbone_address := x"00000000";

  -- WISHBONE crossbar layout
  constant c_INTERCONNECT_LAYOUT      : t_sdb_record_array(4 downto 0) :=
    (0 => f_sdb_embed_device(c_ONEWIRE_SDB_DEVICE,    x"00010000"),
     1 => f_sdb_embed_device(c_TDC_CONFIG_SDB_DEVICE, x"00011000"),
     2 => f_sdb_embed_device(c_TDC_EIC_DEVICE,        x"00012000"),
     3 => f_sdb_embed_device(c_I2C_SDB_DEVICE,        x"00013000"),
     4 => f_sdb_embed_device(c_TDC_MEM_SDB_DEVICE,    x"00014000"));


---------------------------------------------------------------------------------------------------
--                                            Signals                                            --
---------------------------------------------------------------------------------------------------
  -- resets
  signal general_rst_n, rst_ref_0_n: std_logic;
  -- Wishbone buse(s) from crossbar master port(s)
  signal cnx_master_out            : t_wishbone_master_out_array(c_NUM_WB_MASTERS-1 downto 0);
  signal cnx_master_in             : t_wishbone_master_in_array (c_NUM_WB_MASTERS-1 downto 0);
  -- Wishbone buse(s) to crossbar slave port(s)
  signal cnx_slave_out             : t_wishbone_slave_out_array(c_NUM_WB_SLAVES-1 downto 0);
  signal cnx_slave_in              : t_wishbone_slave_in_array (c_NUM_WB_SLAVES-1 downto 0);
  -- Wishbone bus from additional registers
  signal xreg_slave_out            : t_wishbone_slave_out;
  signal xreg_slave_in             : t_wishbone_slave_in;
  -- WISHBONE addresses
  signal tdc_core_wb_adr           : std_logic_vector(31 downto 0);
  signal tdc_mem_wb_adr            : std_logic_vector(31 downto 0);
  -- 1-wire
  signal mezz_owr_en, mezz_owr_i   : std_logic_vector(0 downto 0);
  -- I2C
  signal sys_scl_in, sys_scl_out   : std_logic;
  signal sys_scl_oe_n, sys_sda_in  : std_logic;
  signal sys_sda_out, sys_sda_oe_n : std_logic;
  -- IRQ
  signal irq_tstamp_p, irq_time_p  : std_logic;
  signal irq_acam_err_p            : std_logic;
  -- WRabbit
  signal reg_to_wr, reg_from_wr    : std_logic_vector(31 downto 0);
  signal wrabbit_utc_p             : std_logic;
  signal wrabbit_synched           : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

  rst_ref_0_n <= not(rst_ref_0_i);

---------------------------------------------------------------------------------------------------
--                                     CSR WISHBONE CROSSBAR                                     --
---------------------------------------------------------------------------------------------------
-- CSR wishbone address decoder
--   0x10000 -> TDC core configuration
--   0x11000 -> TDC mezzanine board 1-Wire
--   0x12000 -> EIC for TDC core
--   0x13000 -> TDC mezzanine board EEPROM I2C
--   0x14000 -> TDC core timestamps retrieval

  -- Additional register to help timing
  cmp_xwb_reg : xwb_register_link
  port map
    (clk_sys_i => clk_ref_0_i,
     rst_n_i   => rst_ref_0_n,
     slave_i   => xreg_slave_in,
     slave_o   => xreg_slave_out,
     master_i  => cnx_slave_out(c_WB_MASTER),
     master_o  => cnx_slave_in(c_WB_MASTER));

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Unused wishbone signals
  wb_tdc_csr_dat_o   <= xreg_slave_out.dat;
  wb_tdc_csr_ack_o   <= xreg_slave_out.ack;
  wb_tdc_csr_stall_o <= xreg_slave_out.stall;
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Connect crossbar slave port to entity port
  xreg_slave_in.adr <= wb_tdc_csr_adr_i;
  xreg_slave_in.dat <= wb_tdc_csr_dat_i;
  xreg_slave_in.sel <= wb_tdc_csr_sel_i;
  xreg_slave_in.stb <= wb_tdc_csr_stb_i;
  xreg_slave_in.we  <= wb_tdc_csr_we_i;
  xreg_slave_in.cyc <= wb_tdc_csr_cyc_i;

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cmp_sdb_crossbar : xwb_sdb_crossbar
  generic map
    (g_num_masters  => c_NUM_WB_SLAVES,
     g_num_slaves   => c_NUM_WB_MASTERS,
     g_registered   => true,
     g_wraparound   => true,
     g_layout       => c_INTERCONNECT_LAYOUT,
     g_sdb_addr     => c_SDB_ADDRESS)
  port map
    (clk_sys_i      => clk_ref_0_i,
     rst_n_i        => rst_ref_0_n,
     slave_i        => cnx_slave_in,
     slave_o        => cnx_slave_out,
     master_i       => cnx_master_in,
     master_o       => cnx_master_out);

  
---------------------------------------------------------------------------------------------------
--                                             TDC CORE                                          --
---------------------------------------------------------------------------------------------------
  cmp_tdc_core: fmc_tdc_core
  generic map
    (g_span                  => g_span,
     g_width                 => g_width,
     values_for_simul        => FALSE)
  port map
    (-- clks, rst
     clk_125m_i              => clk_ref_0_i,
     rst_i                   => rst_ref_0_i,
     acam_refclk_r_edge_p_i  => acam_refclk_r_edge_p_i,
     -- DAC configuration
     send_dac_word_p_o       => send_dac_word_p_o,
     dac_word_o              => dac_word_o,
     -- ACAM
     start_from_fpga_o       => start_from_fpga_o,
     err_flag_i              => err_flag_i,
     int_flag_i              => int_flag_i,
     start_dis_o             => start_dis_o,
     stop_dis_o              => stop_dis_o,
     data_bus_io             => data_bus_io,
     address_o               => address_o,
     cs_n_o                  => cs_n_o,
     oe_n_o                  => oe_n_o,
     rd_n_o                  => rd_n_o,
     wr_n_o                  => wr_n_o,
     ef1_i                   => ef1_i,
     ef2_i                   => ef2_i,
     -- Input channels enable
     enable_inputs_o         => enable_inputs_o,
     term_en_1_o             => term_en_1_o,
     term_en_2_o             => term_en_2_o,
     term_en_3_o             => term_en_3_o,
     term_en_4_o             => term_en_4_o,
     term_en_5_o             => term_en_5_o,
     -- Input channels to FPGA (not used currently)
     tdc_in_fpga_1_i         => tdc_in_fpga_1_i,
     tdc_in_fpga_2_i         => tdc_in_fpga_2_i,
     tdc_in_fpga_3_i         => tdc_in_fpga_3_i,
     tdc_in_fpga_4_i         => tdc_in_fpga_4_i,
     tdc_in_fpga_5_i         => tdc_in_fpga_5_i,
     -- TDC board LEDs
     tdc_led_status_o        => tdc_led_status_o,
     tdc_led_trig1_o         => tdc_led_trig1_o,
     tdc_led_trig2_o         => tdc_led_trig2_o,
     tdc_led_trig3_o         => tdc_led_trig3_o,
     tdc_led_trig4_o         => tdc_led_trig4_o,
     tdc_led_trig5_o         => tdc_led_trig5_o,
     -- Interrupts
     irq_tstamp_p_o          => irq_tstamp_p,
     irq_time_p_o            => irq_time_p,
     irq_acam_err_p_o        => irq_acam_err_p,
     -- WR stuff
     wrabbit_tai_i           => wrabbit_utc_i,
     wrabbit_tai_p_i         => wrabbit_utc_p,
     wrabbit_synched_i       => wrabbit_synched,
     wrabbit_status_reg_i    => reg_from_wr,   
     wrabbit_ctrl_reg_o      => reg_to_wr,
     -- WISHBONE CSR for core configuration
     tdc_config_wb_adr_i     => tdc_core_wb_adr,
     tdc_config_wb_dat_i     => cnx_master_out(c_WB_SLAVE_TDC_CORE_CONFIG).dat,
     tdc_config_wb_stb_i     => cnx_master_out(c_WB_SLAVE_TDC_CORE_CONFIG).stb,
     tdc_config_wb_we_i      => cnx_master_out(c_WB_SLAVE_TDC_CORE_CONFIG).we,
     tdc_config_wb_cyc_i     => cnx_master_out(c_WB_SLAVE_TDC_CORE_CONFIG).cyc,
     tdc_config_wb_dat_o     => cnx_master_in(c_WB_SLAVE_TDC_CORE_CONFIG).dat,
     tdc_config_wb_ack_o     => cnx_master_in(c_WB_SLAVE_TDC_CORE_CONFIG).ack,
     -- WISHBONE for timestamps transfer
     tdc_mem_wb_adr_i        => tdc_mem_wb_adr,--wb_tdc_mem_adr_i,
     tdc_mem_wb_dat_i        => cnx_master_out(c_WB_SLAVE_TSTAMP_MEM).dat,
     tdc_mem_wb_stb_i        => cnx_master_out(c_WB_SLAVE_TSTAMP_MEM).stb,
     tdc_mem_wb_we_i         => cnx_master_out(c_WB_SLAVE_TSTAMP_MEM).we,
     tdc_mem_wb_cyc_i        => cnx_master_out(c_WB_SLAVE_TSTAMP_MEM).cyc,
     tdc_mem_wb_ack_o        => cnx_master_in(c_WB_SLAVE_TSTAMP_MEM).ack,
     tdc_mem_wb_dat_o        => cnx_master_in(c_WB_SLAVE_TSTAMP_MEM).dat,
     tdc_mem_wb_stall_o      => cnx_master_in(c_WB_SLAVE_TSTAMP_MEM).stall,
     direct_timestamp_o      => direct_timestamp_o,
     direct_timestamp_stb_o   => direct_timestamp_stb_o);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Convert byte address into word address
  tdc_core_wb_adr <= "00" & cnx_master_out(c_WB_SLAVE_TDC_CORE_CONFIG).adr(31 downto 2);
  tdc_mem_wb_adr  <= "00" & cnx_master_out(c_WB_SLAVE_TSTAMP_MEM).adr(31 downto 2);
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Unused wishbone signals
  cnx_master_in(c_WB_SLAVE_TDC_CORE_CONFIG).err   <= '0';
  cnx_master_in(c_WB_SLAVE_TDC_CORE_CONFIG).rty   <= '0';
  cnx_master_in(c_WB_SLAVE_TDC_CORE_CONFIG).stall <= '0';
  cnx_master_in(c_WB_SLAVE_TDC_CORE_CONFIG).int   <= '0';
  cnx_master_in(c_WB_SLAVE_TSTAMP_MEM).err        <= '0';
  cnx_master_in(c_WB_SLAVE_TSTAMP_MEM).rty        <= '0';
  cnx_master_in(c_WB_SLAVE_TSTAMP_MEM).int        <= '0';


---------------------------------------------------------------------------------------------------
--                                       WHITE RABBIT STUFF                                      --
--                           only synthesized if g_with_wrabbit_core is TRUE                     --
---------------------------------------------------------------------------------------------------
  cmp_wrabbit_synch: wrabbit_sync
  generic map
   (g_simulation               => false,
    g_with_wrabbit_core        => g_with_wrabbit_core)
  port map
    (clk_sys_i                 => clk_sys_i,
     rst_n_sys_i               => rst_sys_n_i,
     clk_ref_i                 => clk_ref_0_i,
     rst_n_ref_i               => rst_ref_0_n,
     wrabbit_dac_value_i       => wrabbit_dac_value_i,
     wrabbit_dac_wr_p_i        => wrabbit_dac_wr_p_i,
     wrabbit_link_up_i         => wrabbit_link_up_i,
     wrabbit_time_valid_i      => wrabbit_time_valid_i,
     wrabbit_clk_aux_lock_en_o => wrabbit_clk_aux_lock_en_o,
     wrabbit_clk_aux_locked_i  => wrabbit_clk_aux_locked_i,
     wrabbit_clk_dmtd_locked_i => '1', -- FIXME
     wrabbit_synched_o         => wrabbit_synched,
     wrabbit_reg_i             => reg_to_wr,    -- synced to 125MHz mezzanine
     wrabbit_reg_o             => reg_from_wr); -- synced to 125MHz mezzanine

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  wrabbit_one_hz_pulse : process(clk_ref_0_i)
  begin
    if rising_edge(clk_ref_0_i) then
      if rst_ref_0_n = '0' then
        wrabbit_utc_p   <= '0';
      else
        if wrabbit_clk_aux_locked_i = '1' and g_with_wrabbit_core then
          if unsigned(wrabbit_cycles_i) = (unsigned(c_SYN_CLK_PERIOD)-3) then -- so that the end of the pulse
                                                                              -- comes exactly upon the UTC change
            wrabbit_utc_p <= '1';
          else
            wrabbit_utc_p <= '0';
          end if;
        else
          wrabbit_utc_p   <= '0';
        end if;
      end if;
    end if;
  end process;


---------------------------------------------------------------------------------------------------
--                        TDC Mezzanine Board UniqueID&Thermometer OneWire                       --
---------------------------------------------------------------------------------------------------
  cmp_fmc_onewire : xwb_onewire_master
  generic map
    (g_interface_mode      => PIPELINED,
     g_address_granularity => BYTE,
     g_num_ports           => 1,
     g_ow_btp_normal       => "5.0",
     g_ow_btp_overdrive    => "1.0")
  port map
    (clk_sys_i             => clk_ref_0_i,
     rst_n_i               => rst_ref_0_n,
     slave_i               => cnx_master_out(c_WB_SLAVE_TDC_ONEWIRE),
     slave_o               => cnx_master_in(c_WB_SLAVE_TDC_ONEWIRE),
     desc_o                => open,
     owr_pwren_o           => open,
     owr_en_o              => mezz_owr_en,
     owr_i                 => mezz_owr_i);
  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  onewire_b                <= '0' when mezz_owr_en(0) = '1' else 'Z';
  mezz_owr_i(0)            <= onewire_b;


---------------------------------------------------------------------------------------------------
--                             WBGEN2 EMBEDDED INTERRUPTS CONTROLLER                             --
---------------------------------------------------------------------------------------------------
-- IRQ sources
-- 0 -> number of accumulated timestamps reached threshold
-- 1 -> number of seconds passed reached threshold and number of accumulated tstamps > 0
-- 2 -> ACAM error
  cmp_tdc_eic : tdc_eic
  port map
    (clk_sys_i          => clk_ref_0_i,
     rst_n_i            => rst_ref_0_n,
     wb_adr_i           => cnx_master_out(c_WB_SLAVE_TDC_EIC).adr(3 downto 2),
     wb_dat_i           => cnx_master_out(c_WB_SLAVE_TDC_EIC).dat,
     wb_dat_o           => cnx_master_in(c_WB_SLAVE_TDC_EIC).dat,
     wb_cyc_i           => cnx_master_out(c_WB_SLAVE_TDC_EIC).cyc,
     wb_sel_i           => cnx_master_out(c_WB_SLAVE_TDC_EIC).sel,
     wb_stb_i           => cnx_master_out(c_WB_SLAVE_TDC_EIC).stb,
     wb_we_i            => cnx_master_out(c_WB_SLAVE_TDC_EIC).we,
     wb_ack_o           => cnx_master_in(c_WB_SLAVE_TDC_EIC).ack,
     wb_stall_o         => cnx_master_in(c_WB_SLAVE_TDC_EIC).stall,
     wb_int_o           => wb_irq_o,
     irq_tdc_tstamps_i  => irq_tstamp_p,
     irq_tdc_time_i     => irq_time_p,
     irq_tdc_acam_err_i => irq_acam_err_p);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Unused wishbone signals
  cnx_master_in(c_WB_SLAVE_TDC_EIC).err <= '0';
  cnx_master_in(c_WB_SLAVE_TDC_EIC).rty <= '0';
  cnx_master_in(c_WB_SLAVE_TDC_EIC).int <= '0';


---------------------------------------------------------------------------------------------------
--                                TDC Mezzanine Board EEPROM I2C                                 --
---------------------------------------------------------------------------------------------------
   cmp_I2C_master : xwb_i2c_master
   generic map
     (g_interface_mode      => PIPELINED,
      g_address_granularity => BYTE)
   port map
     (clk_sys_i             => clk_ref_0_i,
      rst_n_i               => rst_ref_0_n,
      slave_i               => cnx_master_out(c_WB_SLAVE_TDC_I2C),
      slave_o               => cnx_master_in(c_WB_SLAVE_TDC_I2C),
      desc_o                => open,
      scl_pad_i             => i2c_scl_i,
      scl_pad_o             => sys_scl_out,
      scl_padoen_o          => sys_scl_oe_n,
      sda_pad_i             => i2c_sda_i,
      sda_pad_o             => sys_sda_out,
      sda_padoen_o          => sys_sda_oe_n);

  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  i2c_sda_oen_o            <= sys_sda_oe_n;
  i2c_sda_o                <= sys_sda_out;
  i2c_scl_oen_o            <= sys_scl_oe_n;
  i2c_scl_o                <= sys_scl_out;


end rtl;
----------------------------------------------------------------------------------------------------
--  architecture ends
----------------------------------------------------------------------------------------------------