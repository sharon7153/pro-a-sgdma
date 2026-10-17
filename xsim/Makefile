# ============================================================================
# SG DMA simulation with Vivado xsim
#
#   make sim    : compile + elaborate + run (batch, no waveform)
#   make wave   : compile + elaborate + run, dumping all signals to a .wdb
#   make view   : open the .wdb from 'make wave' in the xsim GUI
#   make gui    : compile + elaborate + open the GUI without running
#   make clean  : remove simulation artifacts
#
#   Typical waveform flow:
#       source sourceme
#       make wave
#       make view
# ============================================================================
# Use '>' instead of TAB for recipe lines (safe against editor tab->space)
.RECIPEPREFIX = >

TOP    ?= tb_sg_dma
SNAP   ?= $(TOP)_snap
RTL_F   = ../filelists/rtl.f
TB_F    = ../filelists/tb.f
RUN_TCL = ./xsim_run.tcl
WDB    ?= dump/$(SNAP).wdb

.PHONY: all compile elab sim wave view gui clean

all: sim

compile:
> xvlog     -f $(RTL_F) -log xvlog_rtl.log
> xvlog -sv -f $(TB_F)  -log xvlog_tb.log

elab: compile
> xelab $(TOP) -debug typical -s $(SNAP) -log xelab.log

# batch run, no waveform - this is the regression gate
sim: elab
> xsim $(SNAP) -R -log xsim.log

# batch run with full signal logging -> $(WDB)
#   xsim_run.tcl does:  log_wave -r -v /  ;  run all  ;  quit
wave: elab
> mkdir -p $(dir $(WDB))
> xsim $(SNAP) -wdb $(WDB) -tclbatch $(RUN_TCL) -log xsim_wave.log

# open the dumped waveform
view:
> @test -f $(WDB) || { echo "no $(WDB) - run 'make wave' first"; exit 1; }
> xsim --gui $(WDB) &

# open the GUI on the snapshot itself (add signals by hand, then 'run all')
gui: elab
> xsim $(SNAP) -gui -log xsim.log

clean:
> rm -rf xsim.dir .Xil *.log *.jou *.pb *.str webtalk*
> rm -f  $(WDB)