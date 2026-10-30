###########################################################################
# EE577B Project Phase 2 - Cardinal processor                             #
# Makefile for Cadence NC-Sim (ncvlog / ncelab / ncsim)                    #
#                                                                         #
# Load the course environment first (C shell):                            #
#   % source setup_v1721.csh                                              #
# From bash:                                                              #
#   $ csh -f -c 'source setup_v1721.csh; make sim'                        #
#                                                                         #
#   make / make sim  compile, elaborate and run imem.fill + dmem.fill;    #
#                    writes dmem.dump                                     #
#   make simg        same, in the SimVision GUI                           #
#   make test        make sim; the testbench also compares data memory   #
#                    with expected_dmem.dump                              #
#   make clean       remove all generated files (run before tar-ing)      #
#                                                                         #
# Other programs: make test IMEM=a.fill DMEM=b.fill EXPECTED=c.dump       #
#                                                                         #
# Directory structure                                                     #
#   ./         simulation runs here; imem.fill, dmem.fill                 #
#   ./design   your synthesizable RTL (*.v), top module cardinal_cpu      #
#   ./tb       testbench tb_cardinal_cpu.v                                #
#   ./include  instruction/data memory models (do not modify)             #
#   ./scripts  NC-Sim run scripts                                         #
#   ./work     Cadence work library                                       #
###########################################################################
SHELL := /bin/bash

TOP          = tb_cardinal_cpu
DESIGN_FILES = $(sort $(wildcard ./design/*.v))
TB_FILE      = ./tb/tb_cardinal_cpu.v
INCLUDE_DIRECTORY = ./include

# DesignWare simulation models. SYNOPSYS_DC is set by setup_v1721.csh
# (/tools/synopsys/syn/Y-2026.03 on the vlab servers). List every
# DesignWare component that your design instantiates in DW_COMPONENTS.
SYNOPSYS_DC   ?= /tools/synopsys/syn/Y-2026.03
DW_SIM_DIR     = $(SYNOPSYS_DC)/dw/sim_ver
DW_COMPONENTS  = DW_div DW_sqrt DW02_mult DW01_addsub
DW_SIM_FILES   = $(foreach c,$(DW_COMPONENTS),$(DW_SIM_DIR)/$(c).v)

SIM_SCRIPT_FILE_GUI    = ./scripts/runscript.tcl
SIM_SCRIPT_FILE_NO_GUI = ./scripts/runscript_nogui.tcl

# Program, data, dump and expected-dump files
IMEM     ?= imem.fill
DMEM     ?= dmem.fill
DUMP     ?= dmem.dump
EXPECTED ?= expected_dmem.dump
SIM_ARGS  = +IMEM=$(IMEM) +DMEM=$(DMEM) +DUMP=$(DUMP)

NCVLOG_SWITCHES = \
	-STATUS \
	-MESSAGES \
	-UPDATE \
	-INCDIR $(INCLUDE_DIRECTORY) \
	-INCDIR $(DW_SIM_DIR)

# Port width mismatches and unconnected ports on the processor are errors.
NCELAB_SWITCHES = \
	-ACCESS +rwc \
	-NCFATAL INVSUP \
	-NCFATAL CUNOTB \
	-NCFATAL CUVMPW \
	-NCFATAL CUVWSP \
	-NCFATAL CUVWSI \
	-ERRORMAX 5 \
	-UPDATE \
	-MESSAGES \
	-TIMESCALE '1ns/10ps'

NCSIM_SWITCHES_NO_GUI = \
	-STATUS \
	-NOCOPYRIGHT \
	-MESSAGES \
	-NCFATAL INVSUP \
	-NOWARN DLBRLK \
	-TCL \
	-NOLOG \
	-NOKEY \
	-INPUT $(SIM_SCRIPT_FILE_NO_GUI)

NCSIM_SWITCHES_GUI = \
	-STATUS \
	-NOCOPYRIGHT \
	-MESSAGES \
	-NCFATAL INVSUP \
	-NOWARN DLBRLK \
	-TCL \
	-NOLOG \
	-NOKEY \
	-INPUT $(SIM_SCRIPT_FILE_GUI) \
	-GUI

export TOP

.PHONY: all sim simg test clean
all: sim

ana~: $(DESIGN_FILES) $(TB_FILE)
	@mkdir -p work
	@for f in $(DW_SIM_FILES); do \
		test -r "$$f" || { echo "Missing DesignWare simulation model: $$f" >&2; exit 1; }; \
		ncvlog $(NCVLOG_SWITCHES) -work work "$$f" || exit 1; \
	done
	ncvlog $(NCVLOG_SWITCHES) -work work $(DESIGN_FILES)
	ncvlog $(NCVLOG_SWITCHES) -work work $(TB_FILE)
	@touch ana~

elab~: ana~
	ncelab $(NCELAB_SWITCHES) work.$(TOP)
	@touch elab~

sim: elab~
	@test -r $(IMEM) -a -r $(DMEM) || { echo "Cannot read $(IMEM) and $(DMEM)" >&2; exit 1; }
	@rm -f $(DUMP)
	ncsim $(NCSIM_SWITCHES_NO_GUI) work.$(TOP) $(SIM_ARGS)

simg: elab~
	ncsim $(NCSIM_SWITCHES_GUI) work.$(TOP) $(SIM_ARGS)

test: SIM_ARGS += +EXPECTED=$(EXPECTED)
test: sim

clean:
	@rm -f ana~ elab~ ncvlog.log ncelab.log ncsim.log ncsim.key irun.log xrun.log \
		dmem.dump *.diag *.history
	@rm -rf work INCA_libs xcelium.d ncsim.shm waves.shm xcelium.shm .simvision
	@mkdir -p work
