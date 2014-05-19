---------------------------------------------------------------------------------------
-- Title          : Wishbone slave core for TDC Direct Readout WB Slave
---------------------------------------------------------------------------------------
-- File           : fmc_tdc_direct_readout_slave.vhd
-- Author         : auto-generated by wbgen2 from fmc_tdc_direct_readout_slave.wb
-- Created        : Thu May 15 14:23:14 2014
-- Standard       : VHDL'87
---------------------------------------------------------------------------------------
-- THIS FILE WAS GENERATED BY wbgen2 FROM SOURCE FILE fmc_tdc_direct_readout_slave.wb
-- DO NOT HAND-EDIT UNLESS IT'S ABSOLUTELY NECESSARY!
---------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wbgen2_pkg.all;

use work.dr_wbgen2_pkg.all;


entity fmc_tdc_direct_readout_wb_slave is
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(2 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
    clk_tdc_i                                : in     std_logic;
    regs_i                                   : in     t_dr_in_registers;
    regs_o                                   : out    t_dr_out_registers
  );
end fmc_tdc_direct_readout_wb_slave;

architecture syn of fmc_tdc_direct_readout_wb_slave is

signal dr_fifo_rst_n                            : std_logic      ;
signal dr_fifo_in_int                           : std_logic_vector(86 downto 0);
signal dr_fifo_out_int                          : std_logic_vector(86 downto 0);
signal dr_fifo_rdreq_int                        : std_logic      ;
signal dr_fifo_rdreq_int_d0                     : std_logic      ;
signal dr_chan_enable_int                       : std_logic_vector(4 downto 0);
signal dr_dead_time_int                         : std_logic_vector(23 downto 0);
signal dr_fifo_full_int                         : std_logic      ;
signal dr_fifo_empty_int                        : std_logic      ;
signal dr_fifo_usedw_int                        : std_logic_vector(7 downto 0);
signal ack_sreg                                 : std_logic_vector(9 downto 0);
signal rddata_reg                               : std_logic_vector(31 downto 0);
signal wrdata_reg                               : std_logic_vector(31 downto 0);
signal bwsel_reg                                : std_logic_vector(3 downto 0);
signal rwaddr_reg                               : std_logic_vector(2 downto 0);
signal ack_in_progress                          : std_logic      ;
signal wr_int                                   : std_logic      ;
signal rd_int                                   : std_logic      ;
signal allones                                  : std_logic_vector(31 downto 0);
signal allzeros                                 : std_logic_vector(31 downto 0);

begin
-- Some internal signals assignments. For (foreseen) compatibility with other bus standards.
  wrdata_reg <= wb_dat_i;
  bwsel_reg <= wb_sel_i;
  rd_int <= wb_cyc_i and (wb_stb_i and (not wb_we_i));
  wr_int <= wb_cyc_i and (wb_stb_i and wb_we_i);
  allones <= (others => '1');
  allzeros <= (others => '0');
-- 
-- Main register bank access process.
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      ack_sreg <= "0000000000";
      ack_in_progress <= '0';
      rddata_reg <= "00000000000000000000000000000000";
      dr_chan_enable_int <= "00000";
      dr_dead_time_int <= "000000000000000000000000";
      dr_fifo_rdreq_int <= '0';
    elsif rising_edge(clk_sys_i) then
-- advance the ACK generator shift register
      ack_sreg(8 downto 0) <= ack_sreg(9 downto 1);
      ack_sreg(9) <= '0';
      if (ack_in_progress = '1') then
        if (ack_sreg(0) = '1') then
          ack_in_progress <= '0';
        else
        end if;
      else
        if ((wb_cyc_i = '1') and (wb_stb_i = '1')) then
          case rwaddr_reg(2 downto 0) is
          when "000" => 
            if (wb_we_i = '1') then
              dr_chan_enable_int <= wrdata_reg(4 downto 0);
            end if;
            rddata_reg(4 downto 0) <= dr_chan_enable_int;
            rddata_reg(5) <= 'X';
            rddata_reg(6) <= 'X';
            rddata_reg(7) <= 'X';
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "001" => 
            if (wb_we_i = '1') then
              dr_dead_time_int <= wrdata_reg(23 downto 0);
            end if;
            rddata_reg(23 downto 0) <= dr_dead_time_int;
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "010" => 
            if (wb_we_i = '1') then
            end if;
            if (dr_fifo_rdreq_int_d0 = '0') then
              dr_fifo_rdreq_int <= not dr_fifo_rdreq_int;
            else
              rddata_reg(31 downto 0) <= dr_fifo_out_int(31 downto 0);
              ack_in_progress <= '1';
              ack_sreg(0) <= '1';
            end if;
          when "011" => 
            if (wb_we_i = '1') then
            end if;
            rddata_reg(31 downto 0) <= dr_fifo_out_int(63 downto 32);
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "100" => 
            if (wb_we_i = '1') then
            end if;
            rddata_reg(17 downto 0) <= dr_fifo_out_int(81 downto 64);
            rddata_reg(18) <= dr_fifo_out_int(82);
            rddata_reg(22 downto 19) <= dr_fifo_out_int(86 downto 83);
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "101" => 
            if (wb_we_i = '1') then
            end if;
            rddata_reg(16) <= dr_fifo_full_int;
            rddata_reg(17) <= dr_fifo_empty_int;
            rddata_reg(7 downto 0) <= dr_fifo_usedw_int;
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when others =>
-- prevent the slave from hanging the bus on invalid address
            ack_in_progress <= '1';
            ack_sreg(0) <= '1';
          end case;
        end if;
      end if;
    end if;
  end process;
  
  
-- Drive the data output bus
  wb_dat_o <= rddata_reg;
-- extra code for reg/fifo/mem: Readout FIFO
  dr_fifo_in_int(31 downto 0) <= regs_i.fifo_seconds_i;
  dr_fifo_in_int(63 downto 32) <= regs_i.fifo_cycles_i;
  dr_fifo_in_int(81 downto 64) <= regs_i.fifo_bins_i;
  dr_fifo_in_int(82) <= regs_i.fifo_edge_i;
  dr_fifo_in_int(86 downto 83) <= regs_i.fifo_channel_i;
  dr_fifo_rst_n <= rst_n_i;
  dr_fifo_INST : wbgen2_fifo_async
    generic map (
      g_size               => 256,
      g_width              => 87,
      g_usedw_size         => 8
    )
    port map (
      wr_req_i             => regs_i.fifo_wr_req_i,
      wr_full_o            => regs_o.fifo_wr_full_o,
      wr_empty_o           => regs_o.fifo_wr_empty_o,
      wr_usedw_o           => regs_o.fifo_wr_usedw_o,
      rd_full_o            => dr_fifo_full_int,
      rd_empty_o           => dr_fifo_empty_int,
      rd_usedw_o           => dr_fifo_usedw_int,
      rd_req_i             => dr_fifo_rdreq_int,
      rst_n_i              => dr_fifo_rst_n,
      wr_clk_i             => clk_tdc_i,
      rd_clk_i             => clk_sys_i,
      wr_data_i            => dr_fifo_in_int,
      rd_data_o            => dr_fifo_out_int
    );
  
-- Channel enable
  regs_o.chan_enable_o <= dr_chan_enable_int;
-- Dead time (8ns ticks)
  regs_o.dead_time_o <= dr_dead_time_int;
-- extra code for reg/fifo/mem: FIFO 'Readout FIFO' data output register 0
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      dr_fifo_rdreq_int_d0 <= '0';
    elsif rising_edge(clk_sys_i) then
      dr_fifo_rdreq_int_d0 <= dr_fifo_rdreq_int;
    end if;
  end process;
  
  
-- extra code for reg/fifo/mem: FIFO 'Readout FIFO' data output register 1
-- extra code for reg/fifo/mem: FIFO 'Readout FIFO' data output register 2
  rwaddr_reg <= wb_adr_i;
  wb_stall_o <= (not ack_sreg(0)) and (wb_stb_i and wb_cyc_i);
-- ACK signal generation. Just pass the LSB of ACK counter.
  wb_ack_o <= ack_sreg(0);
end syn;
