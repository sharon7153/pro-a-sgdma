# ============================================================================
# SG DMA simulation with Vivado xsim
#   make sim    : compile + elaborate + run (batch)
#   make gui    : compile + elaborate + open xsim GUI (waveform)
#   make clean  : remove simulation artifacts
# ============================================================================
# Use '>' instead of TAB for recipe lines (safe against editor tab->space)
.RECIPEPREFIX = >

TOP   ?= tb_sg_dma
SNAP  ?= $(TOP)_snap
RTL_F  = ../filelists/rtl.f
TB_F   = ../filelists/tb.f

.PHONY: all compile elab sim gui clean

all: sim

compile:
> xvlog     -f $(RTL_F) -log xvlog_rtl.log
> xvlog -sv -f $(TB_F)  -log xvlog_tb.log

elab: compile
> xelab $(TOP) -debug typical -s $(SNAP) -log xelab.log

sim: elab
> xsim $(SNAP) -R -log xsim.log

gui: elab
> xsim $(SNAP) -gui -log xsim.log

clean:
> rm -rf xsim.dir .Xil *.log *.jou *.pb *.wdb *.str webtalk*