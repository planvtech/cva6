###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = "Example-Project" ##mkdigitals ask for project name
TOP_LEVEL_ENTITY = ####mkdigitals ask for the top level entity
ASSIGNMENT_FILES = $(PROJECT).qpf $(PROJECT).qsf
SOURCES_FILE = ./scripts/sourcelist.txt

###################################################################
# Part, Family, Boardfile DE1 or DE2
## FAMILY COMES FROM THE CALLING MAKEFILE
## PART COMES FROM THE CALLING MAKEFILE
## BOARDFILE COMES FROM THE CALLING MAKEFILE ## mkdigitals ask if there is a board file
###################################################################

###################################################################
# Setup your sources here
SRCS = $(shell cat $(SOURCES_FILE))

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and database
# program: program your device with the compiled design
###################################################################

all: create_project \
	write_settings \
	write_loc_constraints \
	write_io_standard_constraints \
	write_ip_files \
	write_search_paths \
	write_source_files \
	smart.log $(PROJECT).asm.rpt $(PROJECT).sta.rpt

clean:
	$(RM) -rf *.rpt *.chg smart.log *.htm *.eqn *.pin *.sof *.pof db incremental_db *.summary *.smsg *.jdi $(ASSIGNMENT_FILES)
# Capture the Quartus version
QUARTUS_VERSION := $(shell quartus_sh --version | grep -oP 'Version \K[0-9]+\.[0-9]+')
CURRENT_DATETIME := $(shell date +"%H:%M:%S  %B %d, %Y")
create_project:	
	@echo "Creating or regenerating $(PROJECT).qpf"
	@rm -f "$(PROJECT).qpf"
	@touch "$(PROJECT).qpf"
	@echo "QUARTUS_VERSION = \"$(QUARTUS_VERSION)\"" >> "$(PROJECT).qpf"
	@echo "DATE = \"$(CURRENT_DATETIME)\"" >> "$(PROJECT).qpf"
	@echo "PROJECT_REVISION = \"$(PROJECT)\"" >> "$(PROJECT).qpf"

	@echo "Creating or regenerating $(PROJECT).qsf"
	@rm -f "$(PROJECT).qsf"
	@touch "$(PROJECT).qsf"

write_settings:
	@echo "Reading from settings.csv and writing to $(PROJECT).qsf with modifications"
	@while IFS= read -r line; do \
  	echo "set_global_assignment -name $$line" >> "$(PROJECT).qsf"; \
	done < settings.csv

write_loc_constraints:
	@echo "Reading from settings.csv and writing to $(PROJECT).qsf with modifications"
	@while IFS= read -r line; do \
  	echo "set_location_assignment $$line" >> "$(PROJECT).qsf"; \
	done < loc_constraints.csv

write_io_standard_constraints:
	@echo "Reading from settings.csv and writing to $(PROJECT).qsf with modifications"
	@while IFS= read -r line; do \
		echo "set_instance_assignment -name  $$line" >> "$(PROJECT).qsf"; \
	done < io_standard_constraints.csv

write_ip_files:
	@echo "Reading from settings.csv and writing to $(PROJECT).qsf with modifications"
	@while IFS= read -r line; do \
		echo "set_global_assignment -name IP_FILE $$line" >> "$(PROJECT).qsf"; \
	done < ip_files.csv

write_search_paths:
	@echo "Reading from settings.csv and writing to $(PROJECT).qsf with modifications"
	@while IFS= read -r line; do \
		echo "set_global_assignment -name SEARCH_PATH $$line" >> "$(PROJECT).qsf"; \
	done < search_paths.csv

write_source_files:
	@echo "Reading from $(SOURCES_FILE) and writing to $(PROJECT).qsf with modifications"
	@while IFS= read -r line; do \
		for word in $$line; do \
			if echo "$$word" | grep -q "\.vhd$$"; then \
				echo "set_global_assignment -name VHDL_FILE $$word" >> "$(PROJECT).qsf"; \
			elif echo "$$word" | grep -q "\.v$$"; then \
				echo "set_global_assignment -name VERILOG_FILE $$word" >> "$(PROJECT).qsf"; \
			elif echo "$$word" | grep -q "\.sv$$"; then \
				echo "set_global_assignment -name SYSTEMVERILOG_FILE $$word" >> "$(PROJECT).qsf"; \
			elif echo "$$word" | grep -q "\.svh$$"; then \
				echo "set_global_assignment -name SYSTEMVERILOG_FILE $$word" >> "$(PROJECT).qsf"; \
			else \
				echo "set_global_assignment -name SOURCE_FILE $$word" >> "$(PROJECT).qsf"; \
			fi; \
		done; \
	done < $(SOURCES_FILE)
# map: smart.log $(PROJECT).map.rpt
# fit: smart.log $(PROJECT).fit.rpt
# asm: smart.log $(PROJECT).asm.rpt
# sta: smart.log $(PROJECT).sta.rpt
# smart: smart.log

###################################################################
# Executable Configuration
#
# QUARTUS_PATH: If empty then system path is searched.
#               If set then requires trailling slash.
#               Commented out so it may be set from environment.
###################################################################

# QUARTUS_PATH = /opt/altera/13.0sp1/quartus/bin/

# QUARTUS_MAP  = $(QUARTUS_PATH)quartus_syn
# QUARTUS_FIT  = $(QUARTUS_PATH)quartus_fit
# QUARTUS_ASM  = $(QUARTUS_PATH)quartus_asm
# QUARTUS_STA  = $(QUARTUS_PATH)quartus_sta
# QUARTUS_SH   = $(QUARTUS_PATH)quartus_sh
# QUARTUS_PGM  = $(QUARTUS_PATH)quartus_pgm

ifeq ($(shell uname -m),x86_64)
QUARTUS_ARGS = --64bit
endif

MAP_ARGS = $(QUARTUS_ARGS) --read_settings_files=on $(addprefix --source=,$(SRCS))
FIT_ARGS = $(QUARTUS_ARGS) --part=$(PART) --read_settings_files=on
ASM_ARGS = $(QUARTUS_ARGS)
STA_ARGS = $(QUARTUS_ARGS)
SH_ARGS  = $(QUARTUS_ARGS)
PGM_ARGS = $(QUARTUS_ARGS) --no_banner --mode=jtag 

###################################################################
# Target implementations
###################################################################

STAMP = echo done >

$(PROJECT).map.rpt: map.chg $(SOURCE_FILES) 
	$(QUARTUS_MAP) $(MAP_ARGS) $(PROJECT)
	$(STAMP) fit.chg

$(PROJECT).fit.rpt: fit.chg $(PROJECT).map.rpt
	$(QUARTUS_FIT) $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg
	$(STAMP) sta.chg

$(PROJECT).asm.rpt: asm.chg $(PROJECT).fit.rpt
	$(QUARTUS_ASM) $(ASM_ARGS) $(PROJECT)

$(PROJECT).sta.rpt: sta.chg $(PROJECT).fit.rpt
	$(QUARTUS_STA) $(STA_ARGS) $(PROJECT) 

smart.log: $(ASSIGNMENT_FILES)
	$(QUARTUS_SH) $(SH_ARGS) --determine_smart_action $(PROJECT) > smart.log

###################################################################
# Project initialization
###################################################################

$(ASSIGNMENT_FILES):
	$(QUARTUS_SH) $(SH_ARGS) --prepare -f $(FAMILY) -t $(TOP_LEVEL_ENTITY) $(PROJECT)
	-cat $(BOARDFILE) >> $(PROJECT).qsf
map.chg:
	$(STAMP) map.chg
fit.chg:
	$(STAMP) fit.chg
sta.chg:
	$(STAMP) sta.chg
asm.chg:
	$(STAMP) asm.chg

###################################################################
# Programming the device
###################################################################

program: $(PROJECT).sof
	$(QUARTUS_PGM) $(PGM_ARGS) -o "P;$(PROJECT).sof"

program-pof: $(PROJECT).pof
	$(QUARTUS_PGM) $(PGM_ARGS) -o "BVP;$(PROJECT).pof"