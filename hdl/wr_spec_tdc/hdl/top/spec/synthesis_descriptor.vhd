-------------------------------------------------------------------------------
-- Title      : Fine Delay FMC SPEC (Simple PCIe FMC Carrier) SDB descriptor
-- Project    : Fine Delay FMC (fmc-delay-1ns-4cha)
-------------------------------------------------------------------------------
-- File       : synthesis_descriptor.vhd
-- Author     : Evangelia Gousiou
-- Company    : CERN
-- Created    : 2013-04-16
-- Last update: 2013-04-16
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: SDB descriptor for the top level of the FD on a SPEC carrier.
-- Contains synthesis & source repository information.
-- Warning: this file is modified whenever a synthesis is executed.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2013 CERN / BE-CO-HT
--
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------
library ieee;
use ieee.STD_LOGIC_1164.all;
use work.wishbone_pkg.all;

package synthesis_descriptor is
  
constant c_sdb_synthesis_info : t_sdb_synthesis :=
  (
    syn_module_name => "tdc-spec        ",
    syn_commit_id => "00000000000000000000000000000000",
    syn_tool_name => "ISE     ",
    syn_tool_version => x"00000134",
    syn_date => x"00000000",
    syn_username => "egousiou       ");

constant c_sdb_repo_url : t_sdb_repo_url :=
  (
    repo_url => "http://svn.ohwr.org/fmc-tdc                                    " 
  );

end package synthesis_descriptor;
