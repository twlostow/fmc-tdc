#!/bin/bash

wbgen2 -V fmc_tdc_direct_readout_slave.vhd -H record -p fmc_tdc_direct_readout_slave_pkg.vhd -K regs.vh -s defines -C fmctdc-direct.h fmc_tdc_direct_readout_slave.wb
