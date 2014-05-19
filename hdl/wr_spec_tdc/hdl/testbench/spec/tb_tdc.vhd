----------------------------------------------------------------------------------------------------
--  CERN-BE-CO-HT
----------------------------------------------------------------------------------------------------
--
--  unit name   : TDC test-bench (tb_tdc)
--  author      : G. Penacoba
--  date        : May 2011
--  version     : Revision 1
--  description : top module for test-bench
--  dependencies:
--  references  :
--  modified by :
--
----------------------------------------------------------------------------------------------------
--  last changes:
----------------------------------------------------------------------------------------------------
--  to do:
----------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_tdc is
end tb_tdc;

architecture behavioral of tb_tdc is

    component top_tdc
    generic(
        g_span                  : integer :=32;
        g_width                 : integer :=32;
        values_for_simul   : boolean :=FALSE
    );
    port(
        -- interface with GNUM circuit
        rst_n_a_i      : in  std_logic;
        -- P2L Direction
        p2l_clk_p_i : in  std_logic;                      -- Receiver Source Synchronous Clock+
        p2l_clk_n_i : in  std_logic;                      -- Receiver Source Synchronous Clock-
        p2l_data_i  : in  std_logic_vector(15 downto 0);  -- Parallel receive data
        p2l_dframe_i: in  std_logic;                      -- Receive Frame
        p2l_valid_i : in  std_logic;                      -- Receive Data Valid
        p2l_rdy_o   : out std_logic;                      -- Rx Buffer Full Flag
        p_wr_req_i  : in  std_logic_vector(1 downto 0);   -- PCIe Write Request
        p_wr_rdy_o  : out std_logic_vector(1 downto 0);   -- PCIe Write Ready
        rx_error_o  : out std_logic;                      -- Receive Error
        vc_rdy_i    : in  std_logic_vector(1 downto 0);   -- Virtual channel ready
        -- L2P Direction
        l2p_clk_p_o : out std_logic;                      -- Transmitter Source Synchronous Clock+
        l2p_clk_n_o : out std_logic;                      -- Transmitter Source Synchronous Clock-
        l2p_data_o  : out std_logic_vector(15 downto 0);  -- Parallel transmit data
        l2p_dframe_o: out std_logic;                      -- Transmit Data Frame
        l2p_valid_o : out std_logic;                      -- Transmit Data Valid
        l2p_edb_o   : out std_logic;                      -- Packet termination and discard
        l2p_rdy_i   : in  std_logic;                      -- Tx Buffer Full Flag
        l_wr_rdy_i  : in  std_logic_vector(1 downto 0);   -- Local-to-PCIe Write
        p_rd_d_rdy_i: in  std_logic_vector(1 downto 0);   -- PCIe-to-Local Read Response Data Ready
        tx_error_i  : in  std_logic;                      -- Transmit Error
        irq_p_o     : out std_logic;                      -- Interrupt request pulse to GN4124 GPIO

       -- interface signals with PLL circuit
        acam_refclk_p_i           : in std_logic;
        acam_refclk_n_i           : in std_logic;
        --pll_ld_i                : in std_logic;
        --pll_refmon_i            : in std_logic;
        pll_sdo_i               : in std_logic;
        pll_status_i            : in std_logic;
        
        pll_cs_o                : out std_logic;
        pll_dac_sync_o          : out std_logic;
        pll_sdi_o               : out std_logic;
        pll_sclk_o              : out std_logic;
        tdc_clk_p_i             : in std_logic;
        tdc_clk_n_i             : in std_logic;

        -- interface signals with acam (timing)
        err_flag_i              : in std_logic;
        int_flag_i              : in std_logic;

        start_dis_o             : out std_logic;
        start_from_fpga_o       : out std_logic;
        stop_dis_o              : out std_logic;

        -- interface signals with acam (data)
        data_bus_io             : inout std_logic_vector(27 downto 0);
        ef1_i                   : in std_logic;
        ef2_i                   : in std_logic;
        --lf1_i                   : in std_logic;
        --lf2_i                   : in std_logic;

        address_o               : out std_logic_vector(3 downto 0);
        cs_n_o                  : out std_logic;
        oe_n_o                  : out std_logic;
        rd_n_o                  : out std_logic;
        wr_n_o                  : out std_logic;

        -- other signals on the tdc card
        tdc_in_fpga_1_i         : in std_logic;
        tdc_in_fpga_2_i         : in std_logic;
        tdc_in_fpga_3_i         : in std_logic;
        tdc_in_fpga_4_i         : in std_logic;
        tdc_in_fpga_5_i         : in std_logic;


        enable_inputs_o           : out std_logic;
        tdc_led_status_o        : out std_logic;
        tdc_led_trig1_o         : out std_logic;
        tdc_led_trig2_o         : out std_logic;
        tdc_led_trig3_o         : out std_logic;
        tdc_led_trig4_o         : out std_logic;
        tdc_led_trig5_o         : out std_logic;

        carrier_one_wire_b      : inout std_logic;
        sys_scl_b               : inout std_logic;
        sys_sda_b               : inout std_logic;
        mezz_one_wire_b         : inout std_logic;
        pcb_ver_i               : in std_logic_vector(3 downto 0);
        prsnt_m2c_n_i           : in std_logic;

        -- other signals on the spec card
        spec_aux0_i             : in std_logic;
        spec_aux1_i             : in std_logic;
        spec_aux2_o             : out std_logic;
        spec_aux3_o             : out std_logic;
        spec_aux4_o             : out std_logic;
        spec_aux5_o             : out std_logic;
        spec_led_green_o        : out std_logic;
        spec_led_red_o          : out std_logic;
        spec_clk_i              : in std_logic
    );
    end component;

    component acam_model
    generic(
        start_retrig_period     : time:= 3200 ns;
        refclk_period           : time:= 32 ns
    );
    port(
        tstart_i                : in std_logic;
        tstop1_i                : in std_logic;
        tstop2_i                : in std_logic;
        tstop3_i                : in std_logic;
        tstop4_i                : in std_logic;
        tstop5_i                : in std_logic;
        startdis_i              : in std_logic;
        stopdis_i               : in std_logic;

        int_flag_o              : out std_logic;
        err_flag_o              : out std_logic;

        address_i               : in std_logic_vector(3 downto 0);
        cs_n_i                  : in std_logic;
        oe_n_i                  : in std_logic;
        rd_n_i                  : in std_logic;
        wr_n_i                  : in std_logic;
       
        data_bus_io             : inout std_logic_vector(27 downto 0);
        ef1_o                   : out std_logic;
        ef2_o                   : out std_logic;
        lf1_o                   : out std_logic;
        lf2_o                   : out std_logic
    );
    end component;

    component start_stop_gen
    port(
        tstart_o                : out std_logic;
        tstop1_o                : out std_logic;
        tstop2_o                : out std_logic;
        tstop3_o                : out std_logic;
        tstop4_o                : out std_logic;
        tstop5_o                : out std_logic
    );
    end component;

-----------------------------------------------------------------------------
-- GN4124 Local Bus Model
-----------------------------------------------------------------------------
  component GN412X_BFM
    generic
      (
        STRING_MAX     : integer := 256;           -- Command string maximum length
        T_LCLK         : time    := 10 ns;         -- Local Bus Clock Period
        T_P2L_CLK_DLY  : time    := 2 ns;          -- Delay from LCLK to P2L_CLK
        INSTANCE_LABEL : string  := "GN412X_BFM";  -- Label string to be used as a prefix for messages from the model
        MODE_PRIMARY   : boolean := true           -- TRUE for BFM acting as GN412x, FALSE for BFM acting as the DUT
        );
    port
      (
        --=========================================================--
        -------------------------------------------------------------
        -- CMD_ROUTER Interface
        --
        CMD                : in    string(1 to STRING_MAX);
        CMD_REQ            : in    bit;
        CMD_ACK            : out   bit;
        CMD_CLOCK_EN       : in    boolean;
        --=========================================================--
        -------------------------------------------------------------
        -- GN412x Signal I/O
        -------------------------------------------------------------
        -- This is the reset input to the BFM
        --
        RSTINn             : in    std_logic;
        -------------------------------------------------------------
        -- Reset outputs to DUT
        --
        RSTOUT18n          : out   std_logic;
        RSTOUT33n          : out   std_logic;
        -------------------------------------------------------------
        ----------------- Local Bus Clock ---------------------------
        -------------------------------------------------------------  __ Direction for primary mode
        --                                                            / \
        LCLK, LCLKn        : inout std_logic;      -- Out
        -------------------------------------------------------------
        ----------------- Local-to-PCI Dataflow ---------------------
        -------------------------------------------------------------
        -- Transmitter Source Synchronous Clock.
        --
        L2P_CLKp, L2P_CLKn : inout std_logic;      -- In  
        -------------------------------------------------------------
        -- L2P DDR Link
        --
        L2P_DATA           : inout std_logic_vector(15 downto 0);  -- In  -- Parallel Transmit Data.
        L2P_DFRAME         : inout std_logic;  -- In  -- Transmit Data Frame.
        L2P_VALID          : inout std_logic;  -- In  -- Transmit Data Valid. 
        L2P_EDB            : inout std_logic;  -- In  -- End-of-Packet Bad Flag.
        -------------------------------------------------------------
        -- L2P SDR Controls
        --
        L_WR_RDY           : inout std_logic_vector(1 downto 0);  -- Out -- Local-to-PCIe Write.
        P_RD_D_RDY         : inout std_logic_vector(1 downto 0);  -- Out -- PCIe-to-Local Read Response Data Ready.
        L2P_RDY            : inout std_logic;  -- Out -- Tx Buffer Full Flag.
        TX_ERROR           : inout std_logic;  -- Out -- Transmit Error.
        -------------------------------------------------------------
        ----------------- PCIe-to-Local Dataflow ---------------------
        -------------------------------------------------------------
        -- Transmitter Source Synchronous Clock.
        --
        P2L_CLKp, P2L_CLKn : inout std_logic;  -- Out -- P2L Source Synchronous Clock.
        -------------------------------------------------------------
        -- P2L DDR Link
        --
        P2L_DATA           : inout std_logic_vector(15 downto 0);  -- Out -- Parallel Receive Data.
        P2L_DFRAME         : inout std_logic;  -- Out -- Receive Frame.
        P2L_VALID          : inout std_logic;  -- Out -- Receive Data Valid.
        -------------------------------------------------------------
        -- P2L SDR Controls
        --
        P2L_RDY            : inout std_logic;  -- In  -- Rx Buffer Full Flag.
        P_WR_REQ           : inout std_logic_vector(1 downto 0);  -- Out -- PCIe Write Request.
        P_WR_RDY           : inout std_logic_vector(1 downto 0);  -- In  -- PCIe Write Ready.
        RX_ERROR           : inout std_logic;  -- In  -- Receive Error.
        VC_RDY             : inout std_logic_vector(1 downto 0);  -- Out -- Virtual Channel Ready Status.
        -------------------------------------------------------------
        -- GPIO signals
        --
        GPIO               : inout std_logic_vector(15 downto 0)
        );
  end component;  --GN412X_BFM;

-----------------------------------------------------------------------------
-- CMD_ROUTER component
-----------------------------------------------------------------------------
  component cmd_router
    generic(N_BFM      : integer := 8;
            N_FILES    : integer := 3;
            FIFO_DEPTH : integer := 8;
            STRING_MAX : integer := 256
            );
    port(CMD          : out string(1 to STRING_MAX);
         CMD_REQ      : out bit_vector(N_BFM-1 downto 0);
         CMD_ACK      : in  bit_vector(N_BFM-1 downto 0);
         CMD_ERR      : in  bit_vector(N_BFM-1 downto 0);
         CMD_CLOCK_EN : out boolean
         );
  end component;  --cmd_router;

constant pll_clk_period         : time:= 8 ns;
constant g_width                : integer:= 32;
constant g_span                 : integer:= 32;
constant spec_clk_period        : time:= 50 ns;
constant start_retrig_period    : time:= 512 ns;

  -- Number of Models receiving commands
  constant N_BFM      : integer                      := 1;  -- 0 : GN412X_BFM in Model Mode
  --                                                        -- 1 : GN412X_BFM in DUT mode
  -- Number of files to feed BFMs
  constant N_FILES    : integer                      := 1;
  --
  -- Depth of the command FIFO for each model
  constant FIFO_DEPTH : integer                      := 16;
  --
  -- Maximum width of a command string
  constant STRING_MAX : integer                      := 256;

signal acam_refclk_i        : std_logic:='0';
signal acam_refclk_n_i      : std_logic:='1';
signal tdc_clk_p_i          : std_logic:='0';
signal tdc_clk_n_i          : std_logic:='1';
signal spec_clk_i           : std_logic:='0';

signal pll_ld_i             : std_logic;
signal pll_refmon_i         : std_logic;
signal pll_sdo_i            : std_logic;
signal pll_status_i         : std_logic;
        
signal pll_cs_o             : std_logic;
signal pll_dac_sync_o       : std_logic;
signal pll_sdi_o            : std_logic;
signal pll_sclk_o           : std_logic;

signal mute_inputs          : std_logic;

signal address_o            : std_logic_vector(3 downto 0);
signal cs_n_o               : std_logic;
signal data_bus_io          : std_logic_vector(27 downto 0);
signal ef1_i                : std_logic;
signal ef2_i                : std_logic;
signal err_flag_i           : std_logic;
signal int_flag_i           : std_logic;
signal lf1_i                : std_logic;
signal lf2_i                : std_logic;
signal oe_n_o               : std_logic;
signal rd_n_o               : std_logic;
signal start_dis_o          : std_logic;
signal start_from_fpga_o    : std_logic;
signal stop_dis_o           : std_logic;
signal wr_n_o               : std_logic;

--signal tstart               : std_logic;
signal tstop1               : std_logic;
signal tstop2               : std_logic;
signal tstop3               : std_logic;
signal tstop4               : std_logic;
signal tstop5               : std_logic;
signal dummy_tstop5         : std_logic;

signal tdc_in_fpga_5        : std_logic;

signal tdc_led_status       : std_logic;
signal tdc_led_trig1        : std_logic;
signal tdc_led_trig2        : std_logic;
signal tdc_led_trig3        : std_logic;
signal tdc_led_trig4        : std_logic;
signal tdc_led_trig5        : std_logic;
signal spec_aux0_i          : std_logic;
signal spec_aux1_i          : std_logic;
signal spec_aux2_o          : std_logic;
signal spec_aux3_o          : std_logic;
signal spec_aux4_o          : std_logic;
signal spec_aux5_o          : std_logic;
signal spec_led_green       : std_logic;
signal spec_led_red         : std_logic;

  -- GN4124 interface
signal rst_n                : std_logic;
signal irq_p                : std_logic;
signal spare                : std_logic;

  signal RSTINn             : std_logic;
  signal RSTOUT18n          : std_logic;
  signal RSTOUT33n          : std_logic;
  signal LCLK, LCLKn        : std_logic;

  signal P2L_CLKp, P2L_CLKn : std_logic;
  signal P2L_DATA           : std_logic_vector(15 downto 0);
  signal P2L_DATA_32        : std_logic_vector(31 downto 0);  -- For monitoring use
  signal P2L_DFRAME         : std_logic;
  signal P2L_VALID          : std_logic;
  signal P2L_RDY            : std_logic;
  signal P_WR_REQ           : std_logic_vector(1 downto 0);
  signal P_WR_RDY           : std_logic_vector(1 downto 0);
  signal RX_ERROR           : std_logic;
  signal VC_RDY             : std_logic_vector(1 downto 0);
  signal L2P_CLKp, L2P_CLKn : std_logic;
  signal L2P_DATA           : std_logic_vector(15 downto 0);
  signal L2P_DATA_32        : std_logic_vector(31 downto 0);  -- For monitoring use
  signal L2P_DFRAME         : std_logic;
  signal L2P_VALID          : std_logic;
  signal L2P_EDB            : std_logic;
  signal L2P_RDY            : std_logic;
  signal L_WR_RDY           : std_logic_vector(1 downto 0);
  signal P_RD_D_RDY         : std_logic_vector(1 downto 0);
  signal TX_ERROR           : std_logic;
  signal GPIO               : std_logic_vector(15 downto 0);


-----------------------------------------------------------------------------
-- Command Router Signals
-----------------------------------------------------------------------------
  signal CMD          : string(1 to STRING_MAX);
  signal CMD_REQ      : bit_vector(N_BFM-1 downto 0);
  signal CMD_ACK      : bit_vector(N_BFM-1 downto 0);
  signal CMD_ERR      : bit_vector(N_BFM-1 downto 0);
  signal CMD_CLOCK_EN : boolean;

begin

    dut: top_tdc
    generic map(
        g_span                  => 32,
        g_width                 => 32,
        values_for_simul   => TRUE
    )
    port map(
        -- interface with GNUM circuit
        rst_n_a_i               => rst_n,
        p2l_clk_p_i             => p2l_clkp,
        p2l_clk_n_i             => p2l_clkn,
        p2l_data_i              => p2l_data,
        p2l_dframe_i            => p2l_dframe,
        p2l_valid_i             => p2l_valid,
        p2l_rdy_o               => p2l_rdy,
        p_wr_req_i              => p_wr_req,
        p_wr_rdy_o              => p_wr_rdy,
        rx_error_o              => rx_error,
        vc_rdy_i                => vc_rdy,
        l2p_clk_p_o             => l2p_clkp,
        l2p_clk_n_o             => l2p_clkn,
        l2p_data_o              => l2p_data,
        l2p_dframe_o            => l2p_dframe,
        l2p_valid_o             => l2p_valid,
        l2p_edb_o               => l2p_edb,
        l2p_rdy_i               => l2p_rdy,
        l_wr_rdy_i              => l_wr_rdy,
        p_rd_d_rdy_i            => p_rd_d_rdy,
        tx_error_i              => tx_error,
        irq_p_o                 => irq_p,
        
        -- interface with PLL circuit
        acam_refclk_p_i         => acam_refclk_i,
        acam_refclk_n_i         => acam_refclk_n_i,
        --pll_ld_i                => pll_ld_i,
        --pll_refmon_i            => pll_refmon_i,
        pll_sdo_i               => pll_sdo_i,
        pll_status_i            => pll_status_i,
        
        pll_cs_o                => pll_cs_o,
        pll_dac_sync_o          => pll_dac_sync_o,
        pll_sdi_o               => pll_sdi_o,
        pll_sclk_o              => pll_sclk_o,
        tdc_clk_p_i	            => tdc_clk_p_i,
        tdc_clk_n_i	            => tdc_clk_n_i,
        
        -- interface signals with acam (timing)
        int_flag_i          => int_flag_i,
        err_flag_i          => err_flag_i,

        start_dis_o         => start_dis_o,
        start_from_fpga_o   => start_from_fpga_o,
        stop_dis_o          => stop_dis_o,
        
        -- interface signals with acam (data)
        data_bus_io         => data_bus_io,
        ef1_i               => ef1_i,
        ef2_i               => ef2_i,
        --lf1_i               => lf1_i,
        --lf2_i               => lf2_i,
        
        address_o           => address_o,
        cs_n_o              => cs_n_o,
        oe_n_o              => oe_n_o,
        rd_n_o              => rd_n_o,
        wr_n_o              => wr_n_o,
        
        -- other signals on the tdc card
        tdc_in_fpga_5_i     => tdc_in_fpga_5,
        tdc_in_fpga_1_i     => '0',
        tdc_in_fpga_2_i     => '0',
        tdc_in_fpga_3_i     => '0',
        tdc_in_fpga_4_i     => '0',
        enable_inputs_o     => mute_inputs,
        tdc_led_status_o    => tdc_led_status,
        tdc_led_trig1_o     => tdc_led_trig1,
        tdc_led_trig2_o     => tdc_led_trig2,
        tdc_led_trig3_o     => tdc_led_trig3,
        tdc_led_trig4_o     => tdc_led_trig4,
        tdc_led_trig5_o     => tdc_led_trig5,


       
        -- other signals on the spec card
        carrier_one_wire_b  => open,
        sys_scl_b           => open,
        sys_sda_b           => open,
        mezz_one_wire_b     => open,
        pcb_ver_i           => (others => '0'),
        prsnt_m2c_n_i       => '0',
        spec_aux0_i         => spec_aux0_i,
        spec_aux1_i         => spec_aux1_i,
        spec_aux2_o         => spec_aux2_o,
        spec_aux3_o         => spec_aux3_o,
        spec_aux4_o         => spec_aux4_o,
        spec_aux5_o         => spec_aux5_o,
        spec_led_green_o    => spec_led_green,
        spec_led_red_o      => spec_led_red,
        spec_clk_i          => spec_clk_i
    );
    
    acam: acam_model
    generic map(
        start_retrig_period     => start_retrig_period,
        refclk_period           => pll_clk_period/4
    )
    port map(
        tstart_i                => start_from_fpga_o,
        tstop1_i                => tstop1,
        tstop2_i                => tstop2,
        tstop3_i                => tstop3,
        tstop4_i                => tstop4,
        tstop5_i                => tstop5,
--        tstop5_i                => dummy_tstop5,
        startdis_i              => start_dis_o,
        stopdis_i               => stop_dis_o,
        
        int_flag_o              => int_flag_i,
        
        address_i               => address_o,
        cs_n_i                  => cs_n_o,
        oe_n_i                  => oe_n_o,
        rd_n_i                  => rd_n_o,
        wr_n_i                  => wr_n_o,
        
        data_bus_io             => data_bus_io,
        ef1_o                   => ef1_i,
        ef2_o                   => ef2_i,
        err_flag_o              => err_flag_i,
        lf1_o                   => lf1_i,
        lf2_o                   => lf2_i
    );
        
    pulses_generator: start_stop_gen
    port map(
        tstart_o            => open,
        tstop1_o            => tstop1,
        tstop2_o            => tstop2,
        tstop3_o            => tstop3,
        tstop4_o            => tstop4,
        tstop5_o            => tstop5
    );
    
  CMD_ERR <= (others => '0');

  UC : cmd_router
    generic map
    (N_BFM      => N_BFM,
     N_FILES    => N_FILES,
     FIFO_DEPTH => FIFO_DEPTH,
     STRING_MAX => STRING_MAX
     )
    port map
    (CMD          => CMD,
     CMD_REQ      => CMD_REQ,
     CMD_ACK      => CMD_ACK,
     CMD_ERR      => CMD_ERR,
     CMD_CLOCK_EN => CMD_CLOCK_EN
     );

-----------------------------------------------------------------------------
-- GN412x BFM - PRIMARY
-----------------------------------------------------------------------------

  U0 : gn412x_bfm
    generic map
    (
      STRING_MAX     => STRING_MAX,
--      T_LCLK         => 5 ns,
--      T_LCLK         => 10 ns,
      T_LCLK         => 6.25 ns,
      T_P2L_CLK_DLY  => 2 ns,
      INSTANCE_LABEL => "U0(Primary GN412x): ",
      MODE_PRIMARY   => true
      )
    port map
    (
      --=========================================================--
      -------------------------------------------------------------
      -- CMD_ROUTER Interface
      --
      CMD          => CMD,
      CMD_REQ      => CMD_REQ(0),
      CMD_ACK      => CMD_ACK(0),
      CMD_CLOCK_EN => CMD_CLOCK_EN,
      --=========================================================--
      -------------------------------------------------------------
      -- GN412x Signal I/O
      -------------------------------------------------------------
      -- This is the reset input to the BFM
      --
      RSTINn       => RSTINn,
      -------------------------------------------------------------
      -- Reset outputs to DUT
      --
      RSTOUT18n    => RSTOUT18n,
      RSTOUT33n    => RSTOUT33n,
      -------------------------------------------------------------
      ----------------- Local Bus Clock ---------------------------
      ------------------------------------------------------------- 
      --
      LCLK         => LCLK,
      LCLKn        => LCLKn,
      -------------------------------------------------------------
      ----------------- Local-to-PCI Dataflow ---------------------
      -------------------------------------------------------------
      -- Transmitter Source Synchronous Clock.
      --
      L2P_CLKp     => L2P_CLKp,
      L2P_CLKn     => L2P_CLKn,
      -------------------------------------------------------------
      -- L2P DDR Link
      --
      L2P_DATA     => L2P_DATA,
      L2P_DFRAME   => L2P_DFRAME,
      L2P_VALID    => L2P_VALID,
      L2P_EDB      => L2P_EDB,
      -------------------------------------------------------------
      -- L2P SDR Controls
      --
      L_WR_RDY     => L_WR_RDY,
      P_RD_D_RDY   => P_RD_D_RDY,
      L2P_RDY      => L2P_RDY,
      TX_ERROR     => TX_ERROR,
      -------------------------------------------------------------
      ----------------- PCIe-to-Local Dataflow ---------------------
      -------------------------------------------------------------
      -- Transmitter Source Synchronous Clock.
      --
      P2L_CLKp     => P2L_CLKp,
      P2L_CLKn     => P2L_CLKn,
      -------------------------------------------------------------
      -- P2L DDR Link
      --
      P2L_DATA     => P2L_DATA,
      P2L_DFRAME   => P2L_DFRAME,
      P2L_VALID    => P2L_VALID,
      -------------------------------------------------------------
      -- P2L SDR Controls
      --
      P2L_RDY      => P2L_RDY,
      P_WR_REQ     => P_WR_REQ,
      P_WR_RDY     => P_WR_RDY,
      RX_ERROR     => RX_ERROR,
      VC_RDY       => VC_RDY,
      GPIO         => gpio
      );                                -- GN412X_BFM;

    tdc_pll_clock: process
    begin
        if pll_cs_o ='1' and rst_n ='1' then
            tdc_clk_p_i         <= not (tdc_clk_p_i) after 1 ns;
            tdc_clk_n_i         <= not (tdc_clk_n_i) after 1 ns;

            pll_status_i        <= '1';

        end if;
        wait for pll_clk_period/2;
    end process;

    tdc_ref_clock: process
    begin
        if pll_cs_o ='1' and rst_n ='1' then
            acam_refclk_i   <= not (acam_refclk_i) after 3 ns;
        end if;
        wait for pll_clk_period*2;
    end process;
    acam_refclk_n_i <= not acam_refclk_i;

    
    spec_clock: process
    begin
        spec_clk_i           <= not (spec_clk_i) after 1 ns;
        wait for spec_clk_period/2;
    end process;

    rst_n               <= RSTOUT18n;
    GPIO(0)             <= irq_p;
    GPIO(1)             <= spare;
    
    tdc_in_fpga_5       <= tstop5;
    
    spec_aux0_i         <= '1';
    spec_aux1_i         <= '1';

end behavioral;
