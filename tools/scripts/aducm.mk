#------------------------------------------------------------------------------
#                             EXPORTED VARIABLES                               
#------------------------------------------------------------------------------
# Used by nested Makefils (mbedtls, fatfs, iio)
export CFLAGS
export CC
export AR

#------------------------------------------------------------------------------
#                     PLATFORM SPECIFIC INITIALIZATION                               
#------------------------------------------------------------------------------

# New line variable
define ENDL


endef

# Initialize copy_fun and remove_fun
# Initialize CCES_HOME to default, if directory not found show error
#	WINDOWS
ifeq ($(OS), Windows_NT)
SHELL=cmd
copy_fun = copy /Y /B "$(subst /,\,$1)" "$(subst /,\,$2)"
copy_folder = xcopy /S /Y /C /I "$(subst /,\,$1)" "$(subst /,\,$2)"
remove_fun = del /S /Q "$(subst /,\,$1)"
remove_dir = rd /S /Q "$(subst /,\,$1)"
mk_dir = md "$(subst /,\,$1)"
#cces works to but has no console output
CCES = ccesc
CCES_HOME ?= $(wildcard C:/Analog\ Devices/CrossCore*)
ifeq ($(CCES_HOME),)
$(error $(ENDL)$(ENDL)CCES_HOME not found at c:/Analog Devices/[CrossCore...]\
		$(ENDL)$(ENDL)\
Please run command "set CCES_HOME=c:\Analog Devices\[CrossCore...]"$(ENDL)\
Ex: set CCES_HOME=c:\Analog Devices\[CrossCore...] Embedded Studio 2.8.0$(ENDL)$(ENDL))
endif
#	LINUX
else
copy_fun = cp $1 $2
copy_folder = cp -r $1 $2
remove_fun = rm -rf $1
remove_dir = rm -rf $1
mk_dir = mkdir -p $1

CCES = cces
CCES_HOME ?= $(wildcard /opt/analog/cces/*)
ifeq ($(CCES_HOME),)
$(error $(ENDL)$(ENDL)CCES_HOME not found at /opt/analog/cces/[version_number]\
		$(ENDL)$(ENDL)\
		Please run command "export CCES_HOME=[cces_path]"$(ENDL)\
		Ex: export CCES_HOME=/opt/analog/cces/2.9.2$(ENDL)$(ENDL))
endif
endif

#Set PATH variables where used binaries are found
COMPILER_BIN = $(CCES_HOME)/ARM/gcc-arm-embedded/bin
OPENOCD_SCRIPTS = $(CCES_HOME)/ARM/openocd/share/openocd/scripts
OPENOCD_BIN = $(CCES_HOME)/ARM/openocd/bin
CCES_EXE = $(CCES_HOME)/Eclipse

export PATH := $(CCES_EXE):$(OPENOCD_SCRIPTS):$(OPENOCD_BIN):$(COMPILER_BIN):$(PATH)

#------------------------------------------------------------------------------
#                           ENVIRONMENT VARIABLES                              
#------------------------------------------------------------------------------
#SHARED to use in src.mk
PLATFORM		= aducm3029
PROJECT			= $(realpath .)
NO-OS			= $(realpath ../..)
DRIVERS			= $(NO-OS)/drivers
INCLUDE			= $(NO-OS)/include
PLATFORM_DRIVERS	= $(NO-OS)/drivers/platform/$(PLATFORM)

#USED IN MAKEFILE
PROJECT_NAME		= $(notdir $(PROJECT))
BUILD_DIR		= build
PROJECT_BUILD		= $(PROJECT)/aducm_project
WORKSPACE		= $(NO-OS)/projects

PLATFORM_TOOLS		= $(NO-OS)/tools/scripts/platform/$(PLATFORM)

BINARY			= $(BUILD_DIR)/$(PROJECT_NAME)
HEX			= $(PROJECT)/$(PROJECT_NAME).hex

ifneq ($(words $(NO-OS)), 1)
$(error $(ENDL)ERROR:$(ENDL)\
Plese clone no-os in a path without spaces,$(ENDL)\
otherwise the makefile will not work well.$(ENDL)\
Current path is: $(NO-OS)$(ENDL))
endif

#------------------------------------------------------------------------------
#                          FIX SPACES PROBLEM                              
#------------------------------------------------------------------------------

#If dfp have spaces, copy sources from dfp in platform_tools

ADUCM_DFP = $(wildcard \
$(call escape_spaces,$(CCES_HOME))/ARM/packs/AnalogDevices/ADuCM302x_DFP/*)

CMSIS_CORE = $(wildcard \
$(call escape_spaces,$(CCES_HOME))/ARM/packs/ARM/CMSIS/*/CMSIS/Core)

ifneq ($(words $(CCES_HOME)), 1)

ifeq ($(wildcard $(PLATFORM_TOOLS)/dfp_drivers),)
$(warning ERROR:$(ENDL)\
CCES_HOME dir have spaces. To avoid this you can install CCES in a path without\
spaces.$(ENDL)$(ENDL) Or you can copy the dfp into noos running:$(ENDL)$(ENDL)\
 make install_dfp$(ENDL))
else
DFP_DRIVERS = $(PLATFORM_TOOLS)/dfp_drivers

endif

else

DFP_DRIVERS = $(ADUCM_DFP)/Source/drivers

endif

#------------------------------------------------------------------------------
#                           MAKEFILE SOURCES                              
#------------------------------------------------------------------------------

include src.mk

#------------------------------------------------------------------------------
#                     SETTING LIBRARIES IF NEEDED                              
#------------------------------------------------------------------------------

#	MBEDTLS
#If network dir is included, mbedtls will be used
ifneq ($(if $(findstring $(NO-OS)/network, $(SRC_DIRS)), 1),)

MBEDTLS_LIB_NAMES = libmbedcrypto.a libmbedtls.a libmbedx509.a
MBEDTLS_LIB_DIR = $(NO-OS)/libraries/mbedtls/library

LIBS_DIRS	+= "$(MBEDTLS_LIB_DIR)"
LIBS		+= $(MBEDTLS_LIB_NAMES)
INCLUDE_DIRS 	+= $(NO-OS)/libraries/mbedtls/include

CFLAGS 		+= -I $(NO-OS)/network/transport \
			-DMBEDTLS_CONFIG_FILE=\"noos_mbedtls_config.h\"

MBEDTLS_TARGETS	= $(addprefix $(MBEDTLS_LIB_DIR)/,$(MBEDTLS_LIB_NAMES))

ifeq ($(wildcard $(NO-OS)/libraries/mbedtls/LICENSE),)
MBED_TLS_INIT = git submodule update --init --remote -- $(NO-OS)/libraries/mbedtls
endif
#Executed only once if one of the libs needs update

$(MBEDTLS_LIB_DIR)/libmbedcrypto.a:
	$(MAKE) -C $(NO-OS)/libraries/mbedtls lib

$(MBEDTLS_LIB_DIR)/libmbedx509.a: $(MBEDTLS_LIB_DIR)/libmbedcrypto.a

$(MBEDTLS_LIB_DIR)/libmbedtls.a: $(MBEDTLS_LIB_DIR)/libmbedx509.a

CLEAN_MBEDTLS	= $(MAKE) -C $(NO-OS)/libraries/mbedtls clean

endif

#	FATFS
#If fatfs is found in SRC_DIRS
ifneq ($(if $(findstring $(NO-OS)/libraries/fatfs, $(SRC_DIRS)), 1),)
#Remove fatfs from srcdirs because it is a library
SRC_DIRS := $(filter-out $(NO-OS)/libraries/fatfs, $(SRC_DIRS))

FATFS_LIB	= $(NO-OS)/libraries/fatfs/libfatfs.a

LIBS_DIRS	+= "$(dir $(FATFS_LIB))"
LIBS		+= $(notdir $(FATFS_LIB))
INCLUDE_DIRS	+= $(NO-OS)/libraries/fatfs/source

CFLAGS		+= -I$(DRIVERS)/sd-card -I$(INCLUDE)

CLEAN_FATFS	= $(MAKE) -C $(NO-OS)/libraries/fatfs clean
$(FATFS_LIB):
	$(MAKE) -C $(NO-OS)/libraries/fatfs

endif

LIB_FLAGS = $(addprefix -l,$(subst lib,,$(basename $(LIBS))))
LIB_DIR_FLAGS = $(addprefix -L,$(LIBS_DIRS))
LIB_TARGETS = $(MBEDTLS_TARGETS) $(FATFS_LIB)

#------------------------------------------------------------------------------
#                           UTIL FUNCTIONS                              
#------------------------------------------------------------------------------

null :=
SPACE := $(null) $(null)

#This work for wildcards
escape_spaces = $(subst $(SPACE),\$(SPACE),$1)

# Transforme full path to relative path to be used in build
# $(PROJECT)/something -> srcs/something
# $(NO-OS)/something -> noos/something
# $(PLATFORM_TOOLS)/something -> aducm3029/something TODO test without these
get_relative_path = $(patsubst $(NO-OS)%,noos%,$(patsubst $(PLATFORM_TOOLS)%,aducm3029%,$(patsubst $(PROJECT)%,srcs%,$1)))

# Transforme relative path to full path in order to find the needed .c files
# Reverse of get_relative_path
get_full_path = $(patsubst noos%,$(NO-OS)%,$(patsubst aducm3029%,$(PLATFORM_TOOLS)%,$(patsubst srcs%,$(PROJECT)%,$1)))

# recursive wildcard: Same as wildcard but search in subdirectories too
_rwildcard = $(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call _rwildcard,$d/,$2))

#------------------------------------------------------------------------------
#                             DFP DEPENDENCIES                          
#------------------------------------------------------------------------------

#DFP Files
DFP_FILES = $(call _rwildcard,$(DFP_DRIVERS),*.c)
#Not for aducm3029
DFP_IGNORED_FILES += $(DFP_DRIVERS)/flash/adi_flash_data.c $(DFP_DRIVERS)/rtc/adi_rtc_data.c

SRCS += $(filter-out $(DFP_IGNORED_FILES), $(DFP_FILES))

INCS_FLAGS += -I"$(ADUCM_DFP)/Include"
INCS_FLAGS += -I"$(CMSIS_CORE)/Include"

SRCS += $(PROJECT_PIN_MUX)
SRCS += $(PROJECT_BUILD)/system/adi_initialize.c
SRCS += $(PROJECT_BUILD)/RTE/Device/ADuCM3029/startup_ADuCM3029.c
SRCS += $(PROJECT_BUILD)/RTE/Device/ADuCM3029/system_ADuCM3029.c
INCLUDE_DIRS += $(PROJECT_BUILD)/RTE/Device/ADuCM3029
INCLUDE_DIRS += $(PROJECT_BUILD)/RTE
INCLUDE_DIRS += $(PROJECT_BUILD)/system

#ALL directories containing a .h file
INCLUDE_DIRS += $(sort $(foreach dir, $(INCS),$(dir $(dir))))

PIN_MUX = $(PROJECT)/pinmux_config.c
PROJECT_PIN_MUX = $(PROJECT_BUILD)/system/pinmux/GeneratedSources/pinmux_config.c
$(SRCS) += $(PIN_MUX)

REL_SRCS = $(foreach file, $(SRCS), $(BUILD_DIR)/$(call get_relative_path,$(file)))
OBJS = $(REL_SRCS:.c=.o)

#------------------------------------------------------------------------------
#                           COMPILING DATA                              
#------------------------------------------------------------------------------

INCS_FLAGS += $(addprefix -I,$(INCLUDE_DIRS))

CFLAGS	+=	-O2				\
		-ffunction-sections		\
		-fdata-sections			\
		-DCORE0				\
		-DNDEBUG			\
		-D_RTE_				\
		-D__ADUCM3029__			\
		-D__SILICON_REVISION__=0xffff	\
		-Wall				\
		-c -mcpu=cortex-m3		\
		-mthumb				\
		$(INCS_FLAGS)		
#		-Werror

LINKER_FILE	=$(PROJECT_BUILD)/RTE/Device/ADuCM3029/ADuCM3029.ld

LDFLAGS		= -T$(LINKER_FILE)\
		 -Wl,--gc-sections -mcpu=cortex-m3 -mthumb -lm\
		 $(LIB_DIR_FLAGS) $(LIB_FLAGS)
		 


CC = arm-none-eabi-gcc
AR = arm-none-eabi-ar

#------------------------------------------------------------------------------
#                                 RULES                              
#------------------------------------------------------------------------------

.DEFAULT_GOAL := all

# Build project Release Configuration
PHONY := all
ifneq ($(wildcard $(PROJECT_BUILD)),)
all: $(HEX) $(PIN_MUX)
else
all:
	$(MBED_TLS_INIT)
	@$(MAKE) project
	@$(MAKE) $(HEX)
endif

#Used to update pinmux if updated on project
$(PIN_MUX): $(PROJECT_PIN_MUX)
	@echo UPDATEING PINMUX
	$(call copy_fun,$(PROJECT_PIN_MUX),$(PIN_MUX))

PHONY += install_dfp
install_dfp:
	$(call copy_folder,$(ADUCM_DFP)/Source/drivers/*,$(PLATFORM_TOOLS)/dfp_drivers/)

#This is used to keep directory targets between makefile executions
#More details: http://ismail.badawi.io/blog/2017/03/28/automatic-directory-creation-in-make/
#Also the last . is explained
.PRECIOUS: $(BUILD_DIR)/. $(BUILD_DIR)%/.

$(BUILD_DIR)/.:
	-@$(call mk_dir,$@)

$(BUILD_DIR)%/.:
	-@$(call mk_dir,$@)

.SECONDEXPANSION:
$(BUILD_DIR)/%.o: $$(call get_full_path, %).c | $$(@D)/.
	@echo CC -c $(notdir $<) -o $(notdir $@)
	@$(CC) -c $(CFLAGS) $< -o $@

$(BINARY): $(LIB_TARGETS) $(OBJS)
	@echo CC LDFLAGS OBJS INCS_FLAGS -o $(BINARY)
	$(CC) $(LDFLAGS) -o $(BINARY) $(OBJS)

$(HEX): $(BINARY)
	arm-none-eabi-objcopy -O ihex $(BINARY) $(HEX)

# Upload binary to target
PHONY += run
run: all
	openocd -s "$(OPENOCD_SCRIPTS)" -f interface/cmsis-dap.cfg \
		-s "$(ADUCM_DFP)/openocd/scripts" -f target/aducm3029.cfg \
		-c "program  $(BINARY) verify reset exit"

# Remove project binaries
PHONY += clean
clean:
	-$(call remove_fun,$(HEX))
	-$(call remove_dir,$(BUILD_DIR))

# Rebuild porject. SHould we delete project and workspace or just a binary clean?
PHONY += re
re: clean
	@$(MAKE) all

PHONY += ra
ra: clean_all
	@$(MAKE) all

PHONY += clean_libs
clean_libs:
	-$(CLEAN_MBEDTLS)
	-$(CLEAN_FATFS)

# Remove workspace data and project directory
PHONY += clean_all
clean_all: clean
	-$(call remove_dir,$(WORKSPACE)/.metadata)
	-$(call remove_fun,*.target)
	-$(call remove_dir,$(PROJECT_BUILD))

#------------------------------------------------------------------------------
#                             PROJECT RULES                              
#------------------------------------------------------------------------------

PROJECT_BINARY = $(PROJECT_BUILD)/Release/$(PROJECT_NAME)

#This way will not work if the rest button is press or if a printf is executed
#because there is a bug in crossCore that doesn't enable to remove semihosting
#from command line. If semihosting is removed from the IDE this will work to
#CCESS bug: https://labrea.ad.analog.com/browse/CCES-22274
PHONY += project_run
project_run: build_project
	openocd -s "$(OPENOCD_SCRIPTS)" -f interface/cmsis-dap.cfg \
		-s "$(ADUCM_DFP)/openocd/scripts" -f target/aducm3029.cfg \
	-c init \
	-c "program  $(PROJECT_BINARY) verify" \
	-c "arm semihosting enable" \
	-c "reset run" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c exit

PHONY += build_project
build_project: project $(LIB_TARGETS)
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
		-data $(WORKSPACE) \
		-project $(PROJECT_NAME) \
		-build Release

#Flags for each include directory
INCLUDE_FLAGS = $(foreach dir, $(INCLUDE_DIRS),\
		-append-switch compiler -I=$(dir))
#Flags for each linked resource
SRC_FLAGS = $(foreach dir,$(SRC_DIRS),\
		-link $(dir) $(call get_relative_path,$(dir)))

PHONY += update_project
update_project: $(PROJECT_BUILD)/.project.target
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
		-data $(WORKSPACE) \
		-project $(PROJECT_NAME) \
		$(INCLUDE_FLAGS) \
		$(SRC_FLAGS) \
		-append-switch linker additionaloption="$(LIB_FLAGS) $(LIB_DIR_FLAGS)"

PHONY += project
project: $(PROJECT_BUILD)/.project.target

#Create new project with platform driver and utils source folders linked
$(PROJECT_BUILD)/.project.target:
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
		-command projectcreate \
		-data $(WORKSPACE) \
		-project $(PROJECT_BUILD) \
		-project-name $(PROJECT_NAME) \
		-processor ADuCM3029 \
		-type Executable \
		-revision any \
		-language C \
		-config Release \
		-remove-switch linker -specs=rdimon.specs
#Overwrite system.rteconfig file with one that enables all DFP feautres neede by noos
	$(call copy_fun,$(PLATFORM_TOOLS)/system.rteconfig,$(PROJECT_BUILD))
#Adding pinmux plugin (Did not work to add it in the first command) and update project
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
 		-command addaddin \
 		-data $(WORKSPACE) \
 		-project $(PROJECT_NAME) \
 		-id com.analog.crosscore.ssldd.pinmux.component \
		-version latest \
		-regensrc
#The default startup_ADuCM3029.c has compiling errors
#TODO Replace with patch if team think is a better aproch to install a windows
#program for patching	
	$(call copy_fun\
	,$(PLATFORM_TOOLS)/startup_ADuCM3029_patch.c,$(PROJECT_BUILD)/RTE/Device/ADuCM3029/startup_ADuCM3029.c)
#Remove default files from projectsrc
	$(call remove_dir,$(PROJECT_BUILD)/src)
	$(call copy_fun,$(PIN_MUX),$(PROJECT_PIN_MUX))
	@echo "This shouldn't be removed or edited. It is used as make rule" > $@
	@$(MAKE) update_project

PHONY += clean_project
clean_project:
	-$(call remove_dir,$(PROJECT_BUILD)/Release)
#OR	
#	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
 		-data $(WORKSPACE) \
 		-project $(PROJECT_NAME) \
 		-cleanOnly all

.PHONY: $(PHONY)
