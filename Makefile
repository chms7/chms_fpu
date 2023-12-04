# src
PKG += $(wildcard rtl/utils/*.svh)
RTL += $(wildcard rtl/utils/*.*v)
RTL += $(wildcard rtl/*.*v)
TB  := $(wildcard tb/*.sv)

# Tools
SIM_DIR   := sim
SIMV		 	:= $(SIM_DIR)/simv
SIM_TOOL  ?= vcs
SIM_FLAGS := -full64 +v2k -sverilog -kdb -fsdb -ldflags -debug_access+all -LDFLAGS \
						 -Wl,--no-as-needed -Mdir=$(SIM_DIR)/csrc +incdir+rtl/config -o $(SIMV)
WAVE_TOOL ?= gtkwave
WAVE_FILE := $(wildcard sim/*.vcd)

sim:
	@mkdir -p $(SIM_DIR)
	$(SIM_TOOL) $(SIM_FLAGS) $(PKG) $(TB) $(RTL)
	$(SIMV)
	
wave:
	nohup $(WAVE_TOOL) $(WAVE_FILE) >> sim/gtkwave_nohup &
	
clean:
	rm -rf $(SIM_DIR)/* ./ucli.key ./csrc
	
.PHONY: sim wave clean
