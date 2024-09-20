###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT =Example-Project##mkdigitals ask for project name
TOP_LEVEL_ENTITY = ####mkdigitals ask for the top level entity
ASSIGNMENT_FILES = $(PROJECT).qpf $(PROJECT).qsf
SOURCES_FILE = ./scripts/sourcelist.txt
# Define the output bitstream file
BITSTREAM := $(PROJECT).sof
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
	sta

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
	
map:
	@echo "Running Quartus Map"
	$(QUARTUS_PATH)quartus_syn $(PROJECT)

fit: map
	@echo "Running Quartus Fit"
	$(QUARTUS_PATH)quartus_fit $(PROJECT)

asm: fit
	@echo "Running Quartus Assembly"
	$(QUARTUS_PATH)quartus_asm $(PROJECT)

sta: asm
	@echo "Running Quartus Timing Analysis"
	$(QUARTUS_PATH)quartus_sta $(PROJECT)

clean:
	@echo "Cleaning project files"
	rm -f $(PROJECT).qsf $(PROJECT).map.rpt $(PROJECT).fit.rpt $(PROJECT).asm.rpt $(PROJECT).sta.rpt
	rm -rf db incremental_db

.PHONY: all write_search_paths write_source_files map fit asm sta clean