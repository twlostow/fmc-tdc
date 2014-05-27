library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.tdc_core_pkg.all;
use work.wishbone_pkg.all;
use work.dr_wbgen2_pkg.all;

entity fmc_tdc_direct_readout is
  port
    (
      clk_tdc_i   : in std_logic;
      rst_tdc_n_i : in std_logic;

      clk_sys_i   : in std_logic;
      rst_sys_n_i : in std_logic;

      direct_timestamp_i    : in std_logic_vector(127 downto 0);
      direct_timestamp_wr_i : in std_logic;

      direct_slave_i : in  t_wishbone_slave_in;
      direct_slave_o : out t_wishbone_slave_out
      );

end entity;


architecture rtl of fmc_tdc_direct_readout is

  component fmc_tdc_direct_readout_wb_slave is
    port (
      rst_n_i    : in  std_logic;
      clk_sys_i  : in  std_logic;
      wb_adr_i   : in  std_logic_vector(2 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic;
      clk_tdc_i  : in  std_logic;
      regs_i     : in  t_dr_in_registers;
      regs_o     : out t_dr_out_registers);
  end component fmc_tdc_direct_readout_wb_slave;

  constant c_num_channels : integer := 5;

  type t_channel_state is record
    enable  : std_logic;
    timeout : unsigned(23 downto 0);
    fifo_wr : std_logic;
  end record;

  type t_channel_state_array is array(0 to c_num_channels-1) of t_channel_state;

  signal c : t_channel_state_array;

  signal regs_out : t_dr_out_registers;
  signal regs_in  : t_dr_in_registers;

  signal ts_cycles  : std_logic_vector(31 downto 0);
  signal ts_seconds : std_logic_vector(31 downto 0);
  signal ts_bins    : std_logic_vector(17 downto 0);
  signal ts_edge    : std_logic;
  signal ts_channel : std_logic_vector(2 downto 0);

  signal direct_slave_out: t_wishbone_slave_out;
  
begin


  ts_channel <= direct_timestamp_i(98 downto 96);
  ts_edge    <= direct_timestamp_i(100);
  ts_seconds <= direct_timestamp_i(95 downto 64);
  ts_cycles  <= direct_timestamp_i(63 downto 32);
  ts_bins    <= direct_timestamp_i(17 downto 0);

  U_WB_Slave : fmc_tdc_direct_readout_wb_slave
    port map (
      rst_n_i    => rst_sys_n_i,
      clk_sys_i  => clk_sys_i,
      wb_adr_i   => direct_slave_i.adr(4 downto 2),
      wb_dat_i   => direct_slave_i.dat,
      wb_dat_o   => direct_slave_out.dat,
      wb_cyc_i   => direct_slave_i.cyc,
      wb_sel_i   => direct_slave_i.sel,
      wb_stb_i   => direct_slave_i.stb,
      wb_we_i    => direct_slave_i.we,
      wb_ack_o   => direct_slave_out.ack,
      wb_stall_o => direct_slave_out.stall,
      clk_tdc_i  => clk_tdc_i,
      regs_i     => regs_in,
      regs_o     => regs_out);

  direct_slave_out.err <= '0';
  direct_slave_out.rty <= '0';

  direct_slave_o <= direct_slave_out;

  regs_in.fifo_cycles_i  <= ts_cycles;
  regs_in.fifo_edge_i    <= '1';
  regs_in.fifo_seconds_i <= ts_seconds;
  regs_in.fifo_channel_i <= '0'&ts_channel;
  regs_in.fifo_bins_i    <= ts_bins;


  gen_channels : for i in 0 to c_num_channels-1 generate

    p_dead_time : process (clk_tdc_i)
    begin
      if rising_edge(clk_tdc_i) then
        if rst_tdc_n_i = '0' then
          c(i).timeout <= (others => '0');
          c(i).enable  <= '0';
          c(i).fifo_wr <= '0';
        else
          c(i).enable <= regs_out.chan_enable_o(i);

          if c(i).enable = '1' then
            if direct_timestamp_wr_i = '1' and unsigned(ts_channel) = i and ts_edge = '1' and c(i).timeout = 0 then
              c(i).timeout <= unsigned(regs_out.dead_time_o);
              c(i).fifo_wr <= '1';
            elsif c(i).timeout /= 0 then
              c(i).fifo_wr <= '0';
              c(i).timeout <= c(i).timeout - 1;
            end if;
            
          else
            c(i).fifo_wr <= '0';
            c(i).timeout <= (others => '0');
          end if;
        end if;
      end if;
    end process;
    
  end generate gen_channels;

  p_fifo_write : process(clk_tdc_i)
  begin
    if rising_edge(clk_tdc_i) then
      if rst_tdc_n_i = '0' then
        regs_in.fifo_wr_req_i <= '0';
      else
        regs_in.fifo_wr_req_i <= '0';

        for i in 0 to c_num_channels-1 loop
          if(c(i).fifo_wr = '1' and regs_out.fifo_wr_full_o = '0') then
            regs_in.fifo_wr_req_i <= '1';
          end if;
        end loop;
      end if;
    end if;
  end process;

end rtl;


