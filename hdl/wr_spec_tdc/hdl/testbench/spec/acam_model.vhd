-- Creation Date: May 2011
-- Description: reproduced roughly the functionality of the acam:
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity acam_model is
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
end acam_model;

architecture behavioral of acam_model is

    component acam_timing_model
    generic(
        refclk_period           : time:= 32 ns;
        start_retrig_period     : time:= 3200 ns
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
        
        err_flag_o              : out std_logic;
        int_flag_o              : out std_logic;
        start01_o               : out std_logic_vector(16 downto 0);
        timestamp_for_fifo1     : out std_logic_vector(27 downto 0);
        timestamp_for_fifo2     : out std_logic_vector(27 downto 0)
    );
    end component;

    component acam_data_model
    port(
        start01_i               : in std_logic_vector(16 downto 0);
        timestamp_for_fifo1     : in std_logic_vector(27 downto 0);
        timestamp_for_fifo2     : in std_logic_vector(27 downto 0);

        address_i               : in std_logic_vector(3 downto 0);
        cs_n_i                  : in std_logic;
        oe_n_i                  : in std_logic;
        rd_n_i                  : in std_logic;
        wr_n_i                  : in std_logic;
       
        data_bus_o              : out std_logic_vector(27 downto 0);
        ef1_o                   : out std_logic;
        ef2_o                   : out std_logic;
        lf1_o                   : out std_logic;
        lf2_o                   : out std_logic
    );
    end component;

signal timestamp_for_fifo1      : std_logic_vector(27 downto 0);
signal timestamp_for_fifo2      : std_logic_vector(27 downto 0);
signal start01                  : std_logic_vector(16 downto 0);


begin
    
    timing_block: acam_timing_model
    generic map(
        refclk_period           => refclk_period,
        start_retrig_period     => start_retrig_period
    )
    port map(
        tstart_i                => tstart_i,
        tstop1_i                => tstop1_i,
        tstop2_i                => tstop2_i,
        tstop3_i                => tstop3_i,
        tstop4_i                => tstop4_i,
        tstop5_i                => tstop5_i,
        startdis_i              => startdis_i,
        stopdis_i               => stopdis_i,
        
        err_flag_o              => err_flag_o,
        int_flag_o              => int_flag_o,
        start01_o               => start01,
        timestamp_for_fifo1     => timestamp_for_fifo1,
        timestamp_for_fifo2     => timestamp_for_fifo2
    );
    
    data_block: acam_data_model
    port map(
        start01_i               => start01,
        timestamp_for_fifo1     => timestamp_for_fifo1,
        timestamp_for_fifo2     => timestamp_for_fifo2,
        
        address_i               => address_i,
        cs_n_i                  => cs_n_i,
        oe_n_i                  => oe_n_i,
        rd_n_i                  => rd_n_i,
        wr_n_i                  => wr_n_i,
        
        data_bus_o              => data_bus_io,
        ef1_o                   => ef1_o,
        ef2_o                   => ef2_o,
        lf1_o                   => lf1_o,
        lf2_o                   => lf2_o
    );
        

end behavioral;

