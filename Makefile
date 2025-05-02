
#==============================================================================#
#                                  MAKE CONFIG                                 #
#==============================================================================#

MAKE	= make -C
SHELL	:= bash --rcfile ~/.bashrc
CWD		= $(shell pwd)

# .ONESHELL:              # Run all lines in single shell

# Default test values
IN_PATH		?= $(SRC_PATH)
ARG				?= 

#==============================================================================#
#                                     NAMES                                    #
#==============================================================================#

NAME 			 	= babylonTest

### Message Vars
_SUCCESS 		= [$(GRN)SUCCESS$(D)]
_INFO 			= [$(BLU)INFO$(D)]
_SEP	 			= ===================================================

#==============================================================================#
#                                  RULES                                       #
#==============================================================================#

##@ Compilation Rules 🏗

all: deps	## Build Project

deps: install-typescript

install-typescript:
	@echo "$(YEL)Trying to install $(BLU)TypeScript$(D)"
	@if command -v tsc >/dev/null 2>&1; then \
		echo "TypeScript is already installed on this system"; \
	else \
		echo "Installing TypeScript globally..."; \
		sudo npm install -g typescript; \
	fi

##@ Test Rules 🧪

test_all:						## Run All tests
	echo "Test!"

siege_bench:	## Run siege benchmark
	@echo "* $(MAG)$(NAME) $(YEL)under $(BLU)siege$(D) benchmark:"
	siege -b http://localhost:8080

N_USERS ?= 255

siege_concurrent:
	@echo "* $(MAG)$(NAME) $(YEL)under $(BLU)siege$(D) by $(N_USERS) users:"
	siege -c $(N_USERS) http://localhost:8080


posting: env run ## Open posting with Webserrv requests
	@if ! command -v posting &> /dev/null; then \
		echo "Error: 'posting' command not found. Make sure it's installed."; \
		exit 1; \
	fi
	posting --collection $(POSTING)  --env .env

station: ## Run Webserv w/ posting station
	@if ! command -v tmux &> /dev/null; then \
		echo "Error: 'tmux' command not found. Make sure it's installed."; \
		exit 1; \
	fi
	tmux split-window -v "make exec"
	tmux split-window -h "make posting"
	tmux resize-pane -U 25
	tmux resize-pane -L 25

curl_resolve:
	curl --resolve example.com:8080:127.0.0.1 http://example.com:8080/

curl_body_size:
	curl -X POST -H "Content-Type: plain/text" --data "$(printf 'A%0.s' {1..1024})" http://localhost:8080/limited -v

##@ Debug Rules 

gdb: debug $(NAME) $(TEMP_PATH)			## Debug w/ gdb
	tmux split-window -h "gdb --tui --args ./$(NAME)"
	tmux resize-pane -L 5
	# tmux split-window -v "btop"
	make get_log

vgdb: debug $(NAME) $(TEMP_PATH)			## Debug w/ valgrind (memcheck) & gdb
	tmux split-window -h "valgrind $(VGDB_ARGS) --log-file=gdb.txt ./$(NAME) $(ARG)"
	make vgdb_cmd
	tmux split-window -v "gdb --tui -x $(TEMP_PATH)/gdb_commands.txt $(NAME)"
	tmux resize-pane -U 18
	# tmux split-window -v "btop"
	make get_log

valgrind: debug $(NAME) $(TEMP_PATH)			## Debug w/ valgrind (memcheck)
	tmux set-option remain-on-exit on
	tmux split-window -h "valgrind $(VAL_ARGS) ./$(NAME) $(ARG)"

massif: all $(TEMP_PATH)		## Run Valgrind w/ Massif (gather profiling information)
	@TIMESTAMP=$(shell date +%Y%m%d%H%M%S); \
	if [ -f massif.out.* ]; then \
		mv -f massif.out.* $(TEMP_PATH)/massif.out.$$TIMESTAMP; \
	fi
	@echo " 🔎 [$(YEL)Massif Profiling$(D)]"
	valgrind --tool=massif --time-unit=B ./$(NAME) $(ARG)
	ms_print massif.out.*
# Learn more about massif and ms_print:
### https://valgrind.org/docs/manual/ms-manual.html

get_log:
	touch gdb.txt
	@if command -v lnav; then \
		lnav gdb.txt; \
	else \
		tail -f gdb.txt; \
	fi

vgdb_cmd: $(NAME) $(TEMP_PATH)
	@printf "target remote | vgdb --pid=" > $(TEMP_PATH)/gdb_commands.txt
	@printf "$(shell pgrep -f valgrind)" >> $(TEMP_PATH)/gdb_commands.txt
	@printf "\n" >> $(TEMP_PATH)/gdb_commands.txt
	@cat .vgdbinit >> $(TEMP_PATH)/gdb_commands.txt

##@ Clean-up Rulecurl --resolve example.com:8080:127.0.0.1 http://example.com/s 󰃢

clean: 				## Remove object files
	@echo "*** $(YEL)Removing $(MAG)$(NAME)$(D) and deps $(YEL)object files$(D)"
	@if [ -d "$(BUILD_PATH)" ] || [ -d "$(TEMP_PATH)" ]; then \
		if [ -d "$(BUILD_PATH)" ]; then \
			$(RM) $(BUILD_PATH); \
			echo "* $(YEL)Removing $(CYA)$(BUILD_PATH)$(D) folder & files$(D): $(_SUCCESS)"; \
		fi; \
		if [ -d "$(TEMP_PATH)" ]; then \
			$(RM) $(TEMP_PATH); \
			echo "* $(YEL)Removing $(CYA)$(TEMP_PATH)$(D) folder & files:$(D) $(_SUCCESS)"; \
		fi; \
	else \
		echo " $(RED)$(D) [$(GRN)Nothing to clean!$(D)]"; \
	fi

fclean: clean			## Remove executable and .gdbinit
	@if [ -f "$(NAME)" ]; then \
		if [ -f "$(NAME)" ]; then \
			$(RM) $(NAME); \
			$(RM) ~/data; \
			echo "* $(YEL)Removing $(CYA)$(NAME)$(D) file: $(_SUCCESS)"; \
		fi; \
	else \
		echo " $(RED)$(D) [$(GRN)Nothing to be fcleaned!$(D)]"; \
	fi

re: fclean all	## Purge & Recompile

##@ Help 󰛵

help: 			## Display this help page
	@awk 'BEGIN {FS = ":.*##"; \
			printf "\n=> Usage:\n\tmake $(GRN)<target>$(D)\n"} \
		/^[a-zA-Z_0-9-]+:.*?##/ { \
			printf "\t$(GRN)%-18s$(D) %s\n", $$1, $$2 } \
		/^##@/ { \
			printf "\n=> %s\n", substr($$0, 5) } ' Makefile
## Tweaked from source:
### https://www.padok.fr/en/blog/beautiful-makefile-awk

.PHONY: bonus clean fclean re help

#==============================================================================#
#                                  UTILS                                       #
#==============================================================================#

# Colors
#
# Run the following command to get list of available colors
# bash -c 'for c in {0..255}; do tput setaf $c; tput setaf $c | cat -v; echo =$c; done'

B  		= $(shell tput bold)
BLA		= $(shell tput setaf 0)
RED		= $(shell tput setaf 1)
GRN		= $(shell tput setaf 2)
YEL		= $(shell tput setaf 3)
BLU		= $(shell tput setaf 4)
MAG		= $(shell tput setaf 5)
CYA		= $(shell tput setaf 6)
WHI		= $(shell tput setaf 7)
GRE		= $(shell tput setaf 8)
BRED 	= $(shell tput setaf 9)
BGRN	= $(shell tput setaf 10)
BYEL	= $(shell tput setaf 11)
BBLU	= $(shell tput setaf 12)
BMAG	= $(shell tput setaf 13)
BCYA	= $(shell tput setaf 14)
BWHI	= $(shell tput setaf 15)
D 		= $(shell tput sgr0)
BEL 	= $(shell tput bel)
CLR 	= $(shell tput el 1)

