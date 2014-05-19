--_________________________________________________________________________________________________
--                                                                                                |
--                                           |TDC core|                                           |
--                                                                                                |
--                                         CERN,BE/CO-HT                                          |
--________________________________________________________________________________________________|

---------------------------------------------------------------------------------------------------
--                                                                                                |
--                                         sdb_meta_pkg                                           |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         sdb_meta_pkg.vhd                                                                  |
--                                                                                                |
-- Description  Sdb meta-information for the FMC TDC design for SPEC.                             |
--                                                                                                |
-- Authors      Matthieu Cattin (matthieu.cattin@cern.ch)                                         |
--              Evangelia Gousiou (Evangelia.Gousiou@cern.ch)                                     |
-- Date         04/2013                                                                           |
-- Version      v1                                                                                |
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

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wishbone_pkg.all;

package sdb_meta_pkg is

  ------------------------------------------------------------------------------
  -- Meta-information sdb records
  ------------------------------------------------------------------------------

  -- Top module repository url
  constant c_SDB_REPO_URL : t_sdb_repo_url := (
    -- url (string, 63 char)
    repo_url => "http://svn.ohwr.org/fmc-tdc/hdl/spec/                          ");

  -- Synthesis informations
  constant c_SDB_SYNTHESIS : t_sdb_synthesis := (
    -- Top module name (string, 16 char)
    syn_module_name  => "spec_top_fmc_tdc",
    -- Commit ID (hex string, 128-bit = 32 char)
    -- git log -1 --format="%H" | cut -c1-320
    syn_commit_id    => x"00000000",
    -- Synthesis tool name (string, 8 char)
    syn_tool_name    => "ISE     ",
    -- Synthesis tool version (bcd encoded, 32-bit)
    syn_tool_version => x"00000134",
    -- Synthesis date (bcd encoded, 32-bit)
    syn_date         => x"20140121",
    -- Synthesised by (string, 15 char)
    syn_username     => "egousiou       ");

  -- Integration record
  constant c_SDB_INTEGRATION : t_sdb_integration := (
    product     => (
      vendor_id => x"000000000000CE42",  -- CERN
      device_id => x"593b56e5",          -- echo "spec_fmc-tdc-1ns5cha" | md5sum | cut -c1-8
      version   => x"00050000",          -- bcd encoded, [31:16] = major, [15:0] = minor
      date      => x"20140121",          -- yyyymmdd
      name      => "spec_top_fmc_tdc   "));


end sdb_meta_pkg;


package body sdb_meta_pkg is
end sdb_meta_pkg;