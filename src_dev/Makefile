# MV202611 common static library and offline consumer (GNU Make / POSIX shell).
# Keep generated files outside the checkout; use a separate BUILD_ROOT for each
# compiler/flag profile. See README.md for Windows and Linux examples.
.DEFAULT_GOAL := all
ifneq (,$(filter 0 1 2 3,$(firstword $(subst ., ,$(MAKE_VERSION)))))
$(error GNU Make 4.0 or newer is required for response-file generation)
endif

include gfortran_args
include make/teb_sources.mk

# Native Windows defaults to the workstation's external work root. On other
# machines select TEB_WORK_ROOT or BUILD_ROOT explicitly. Legacy absolute
# OBJDIR/EXEC overrides remain supported; an explicit OBJDIR owns its profile.
ifeq ($(OS),Windows_NT)
TEB_WORK_ROOT ?= W:/Work_TEB
endif
PROFILE ?= $(notdir $(FC))-dev
ifeq ($(strip $(BUILD_ROOT)),)
ifneq ($(strip $(OBJDIR)),)
BUILD_ROOT := $(abspath $(subst \,/,$(OBJDIR)))
else ifneq ($(strip $(TEB_WORK_ROOT)),)
BUILD_ROOT := $(TEB_WORK_ROOT)/TEB-Ru/default/build/$(PROFILE)
endif
endif

OBJDIR ?= $(BUILD_ROOT)/common/obj
MODDIR ?= $(BUILD_ROOT)/common/mod
OFFLINE_OBJDIR ?= $(BUILD_ROOT)/offline/obj
OFFLINE_MODDIR ?= $(BUILD_ROOT)/offline/mod
BLOCK_OBJDIR ?= $(BUILD_ROOT)/offline-block/obj
BLOCK_MODDIR ?= $(BUILD_ROOT)/offline-block/mod
PLATFORM_OBJDIR ?= $(BUILD_ROOT)/platform/obj
LIB ?= $(BUILD_ROOT)/lib/libteb.a
EXEC ?= $(BUILD_ROOT)/bin/TEB_offline_dev.exe
BLOCK_EXEC ?= $(BUILD_ROOT)/bin/TEB_offline_block_dev.exe

# A relative or in-checkout output path would violate AGENTS.md. Validate every
# override before any recipe (including clean) can write or remove a file.
REPO_ROOT := $(abspath ..)
ACTIVE_GOALS := $(if $(MAKECMDGOALS),$(filter-out help,$(MAKECMDGOALS)),all)
ifneq ($(strip $(ACTIVE_GOALS)),)
ifeq ($(strip $(BUILD_ROOT)),)
$(error Set BUILD_ROOT or TEB_WORK_ROOT to an absolute external directory)
endif
define validate_output
$(if $(or $(filter /%,$(subst \,/,$($(1)))),$(findstring :/,$(subst \,/,$($(1))))),,$(error $(1) must be an absolute external path))
$(if $(filter $(REPO_ROOT) $(REPO_ROOT)/%,$(abspath $(subst \,/,$($(1))))),$(error $(1) must be outside the repository),)
endef
$(foreach name,BUILD_ROOT OBJDIR MODDIR OFFLINE_OBJDIR OFFLINE_MODDIR BLOCK_OBJDIR BLOCK_MODDIR PLATFORM_OBJDIR LIB EXEC BLOCK_EXEC,$(eval $(call validate_output,$(name))))
endif

# Use one canonical slash spelling in Make targets and compiler arguments.
override BUILD_ROOT := $(subst \,/,$(BUILD_ROOT))
override OBJDIR := $(subst \,/,$(OBJDIR))
override MODDIR := $(subst \,/,$(MODDIR))
override OFFLINE_OBJDIR := $(subst \,/,$(OFFLINE_OBJDIR))
override OFFLINE_MODDIR := $(subst \,/,$(OFFLINE_MODDIR))
override BLOCK_OBJDIR := $(subst \,/,$(BLOCK_OBJDIR))
override BLOCK_MODDIR := $(subst \,/,$(BLOCK_MODDIR))
override PLATFORM_OBJDIR := $(subst \,/,$(PLATFORM_OBJDIR))
override LIB := $(subst \,/,$(LIB))
override EXEC := $(subst \,/,$(EXEC))
override BLOCK_EXEC := $(subst \,/,$(BLOCK_EXEC))

COMMON_STEMS := $(basename $(notdir $(COMMON_SRC)))
OFFLINE_STEMS := $(basename $(notdir $(OFFLINE_SRC)))
BLOCK_STEMS := $(basename $(notdir $(BLOCK_SRC)))
COMMON_OBJ := $(addprefix $(OBJDIR)/,$(addsuffix .o,$(COMMON_STEMS)))
OFFLINE_OBJ := $(addprefix $(OFFLINE_OBJDIR)/,$(addsuffix .o,$(OFFLINE_STEMS)))
OFFLINE_SUPPORT_OBJ := $(filter-out $(OFFLINE_OBJDIR)/run_teb_offline.o,$(OFFLINE_OBJ))
BLOCK_OBJ := $(addprefix $(BLOCK_OBJDIR)/,$(addsuffix .o,$(BLOCK_STEMS)))
include make/teb_dependencies.mk

FC_NAME := $(notdir $(firstword $(FC)))
ifneq (,$(filter ifort ifort.exe,$(FC_NAME)))
COMMON_MODFLAGS = -module $(MODDIR) -I$(MODDIR)
OFFLINE_MODFLAGS = -module $(OFFLINE_MODDIR) -I$(MODDIR) -I$(OFFLINE_MODDIR)
BLOCK_MODFLAGS = -module $(BLOCK_MODDIR) -I$(MODDIR) -I$(OFFLINE_MODDIR) -I$(BLOCK_MODDIR)
else
COMMON_MODFLAGS = -J$(MODDIR) -I$(MODDIR)
OFFLINE_MODFLAGS = -J$(OFFLINE_MODDIR) -I$(MODDIR) -I$(OFFLINE_MODDIR)
BLOCK_MODFLAGS = -J$(BLOCK_MODDIR) -I$(MODDIR) -I$(OFFLINE_MODDIR) -I$(BLOCK_MODDIR)
endif

# The UCRT workaround belongs to final executables, not to the physics archive.
# Library consumers on Windows/GNU use the same optional platform object/flags.
WRAP_LOCALE ?= $(if $(filter Windows_NT,$(OS)),1,0)
PLATFORM_OBJ :=
PLATFORM_LDFLAGS :=
ifeq ($(WRAP_LOCALE),1)
ifneq (,$(findstring gfortran,$(FC_NAME)))
PLATFORM_OBJ := $(PLATFORM_OBJDIR)/wrap_setlocale.o
PLATFORM_LDFLAGS := -static-libgfortran -Wl,--wrap=setlocale
endif
endif

LIBDIR := $(patsubst %/,%,$(dir $(LIB)))
EXECDIR := $(patsubst %/,%,$(dir $(EXEC)))
BLOCK_EXECDIR := $(patsubst %/,%,$(dir $(BLOCK_EXEC)))
OUTPUT_DIRS := $(sort $(BUILD_ROOT) $(OBJDIR) $(MODDIR) $(OFFLINE_OBJDIR) $(OFFLINE_MODDIR) $(BLOCK_OBJDIR) $(BLOCK_MODDIR) $(PLATFORM_OBJDIR) $(LIBDIR) $(EXECDIR) $(BLOCK_EXECDIR))
PROFILE_FILE := $(BUILD_ROOT)/build-profile.txt

.PHONY: all library offline offline-block platform help print-config profile-check force-module clean neat
all: offline
library: $(LIB)
offline: $(EXEC)
offline-block: $(BLOCK_EXEC)
platform: $(PLATFORM_OBJ)
force-module:

$(OUTPUT_DIRS):
	mkdir -p "$@"

# A profile is immutable with respect to compilation settings. This catches a
# stale .o/.mod mixture instead of silently reusing it with different flags.
profile-check: | $(BUILD_ROOT)
	@set -eu; tmp="$(PROFILE_FILE).tmp.$$$$"; \
	printf '%s\n' 'SOURCE=$(CURDIR)' 'FC=$(FC)' 'FFLAGS=$(FFLAGS)' 'OTHERFLAGS=$(OTHERFLAGS)' 'CPPDEFS=$(CPPDEFS)' 'CPPFLAGS=$(CPPFLAGS)' 'CC=$(CC)' 'LD=$(LD)' 'LDFLAGS=$(LDFLAGS)' 'AR=$(AR)' 'ARFLAGS=$(ARFLAGS)' 'WRAP_LOCALE=$(WRAP_LOCALE)' 'OBJDIR=$(OBJDIR)' 'MODDIR=$(MODDIR)' 'OFFLINE_OBJDIR=$(OFFLINE_OBJDIR)' 'OFFLINE_MODDIR=$(OFFLINE_MODDIR)' 'BLOCK_OBJDIR=$(BLOCK_OBJDIR)' 'BLOCK_MODDIR=$(BLOCK_MODDIR)' 'BLOCK_EXEC=$(BLOCK_EXEC)' 'PLATFORM_OBJDIR=$(PLATFORM_OBJDIR)' 'LIB=$(LIB)' 'EXEC=$(EXEC)' > "$$tmp"; \
	if [ -f "$(PROFILE_FILE)" ]; then \
	  old_profile=$$(cat "$(PROFILE_FILE)"); new_profile=$$(cat "$$tmp"); \
	  if [ "$$old_profile" != "$$new_profile" ]; then \
	    rm -f "$$tmp"; \
	    echo 'Build profile differs: choose a new BUILD_ROOT or clean this profile.' >&2; exit 1; \
	  fi; rm -f "$$tmp"; \
	else mv "$$tmp" "$(PROFILE_FILE)"; fi

$(COMMON_OBJ): gfortran_args make/teb_sources.mk make/teb_dependencies.mk Makefile | $(OBJDIR) $(MODDIR) profile-check
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) $(COMMON_MODFLAGS) -c $(filter %.F90 %.f90 %.F %.f,$^) -o "$@"

$(OFFLINE_OBJ): gfortran_args make/teb_sources.mk make/teb_dependencies.mk Makefile | $(OFFLINE_OBJDIR) $(OFFLINE_MODDIR) profile-check
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) $(OFFLINE_MODFLAGS) -c $(filter %.F90 %.f90 %.F %.f,$^) -o "$@"

$(BLOCK_OBJ): gfortran_args make/teb_sources.mk make/teb_dependencies.mk Makefile | $(BLOCK_OBJDIR) $(BLOCK_MODDIR) profile-check
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) $(BLOCK_MODFLAGS) -c $(filter %.F90 %.f90 %.F %.f,$^) -o "$@"

# Recover a deleted module by rebuilding its provider once. Dependents already
# name that provider object, so parallel compilation preserves the USE order.
missing_modules = $(filter-out $(wildcard $(addprefix $(1)/,$(addsuffix .mod,$(TEB_MODULES_$(2))))),$(addprefix $(1)/,$(addsuffix .mod,$(TEB_MODULES_$(2)))))
$(foreach stem,$(COMMON_STEMS),$(if $(call missing_modules,$(MODDIR),$(stem)),$(eval $(OBJDIR)/$(stem).o: force-module)))
$(foreach stem,$(OFFLINE_STEMS),$(if $(call missing_modules,$(OFFLINE_MODDIR),$(stem)),$(eval $(OFFLINE_OBJDIR)/$(stem).o: force-module)))
$(foreach stem,$(BLOCK_STEMS),$(if $(call missing_modules,$(BLOCK_MODDIR),$(stem)),$(eval $(BLOCK_OBJDIR)/$(stem).o: force-module)))

# Start with a fresh archive so removed manifest members cannot survive a rebuild.
$(LIB): $(COMMON_OBJ) make/teb_sources.mk Makefile | $(LIBDIR) profile-check
	$(file >$(LIB).objects.rsp,$(COMMON_OBJ))
	$(RM) "$(LIB).tmp"
	$(AR) $(ARFLAGS) "$(LIB).tmp" @"$(LIB).objects.rsp"
	mv -f "$(LIB).tmp" "$(LIB)"

$(EXEC): $(OFFLINE_OBJ) $(LIB) $(PLATFORM_OBJ) Makefile gfortran_args | $(EXECDIR) profile-check
	$(LD) $(OFFLINE_OBJ) "$(LIB)" $(PLATFORM_OBJ) -o "$@" $(LDFLAGS) $(PLATFORM_LDFLAGS)

$(BLOCK_EXEC): $(BLOCK_OBJ) $(OFFLINE_SUPPORT_OBJ) $(LIB) $(PLATFORM_OBJ) Makefile gfortran_args | $(BLOCK_EXECDIR) profile-check
	$(LD) $(BLOCK_OBJ) $(OFFLINE_SUPPORT_OBJ) "$(LIB)" $(PLATFORM_OBJ) -o "$@" $(LDFLAGS) $(PLATFORM_LDFLAGS)

$(PLATFORM_OBJDIR)/wrap_setlocale.o: src_driver/wrap_setlocale.c Makefile | $(PLATFORM_OBJDIR) profile-check
	$(CC) -O0 -g -c $< -o "$@"

print-config:
	@printf '%s\n' 'BUILD_ROOT=$(BUILD_ROOT)' 'LIB=$(LIB)' 'MODDIR=$(MODDIR)' 'OBJDIR=$(OBJDIR)' 'OFFLINE_MODDIR=$(OFFLINE_MODDIR)' 'OFFLINE_OBJDIR=$(OFFLINE_OBJDIR)' 'EXEC=$(EXEC)' 'PLATFORM_OBJ=$(PLATFORM_OBJ)' 'PLATFORM_LDFLAGS=$(PLATFORM_LDFLAGS)' 'COMMON_OBJECTS=$(words $(COMMON_OBJ))' 'OFFLINE_OBJECTS=$(words $(OFFLINE_OBJ))' 'BLOCK_EXEC=$(BLOCK_EXEC)' 'BLOCK_OBJECTS=$(words $(BLOCK_OBJ))'

help:
	@printf '%s\n' 'Targets: library, offline (default all), offline-block, platform, print-config, clean' 'Select FC/LD and an absolute external BUILD_ROOT; use a new root for different flags.' 'Windows: use the matching MSYS2 POSIX shell (SHELL=.../usr/bin/sh.exe).' 'Common and offline .o/.mod files are separate; .mod files are compiler-specific.'

# Remove only this manifest/profile's named artifacts; never recursively delete
# a caller-supplied directory or search the source tree for module files.
neat:
	$(RM) "$(LIB).tmp"
CLEAN_FILES = $(COMMON_OBJ) $(OFFLINE_OBJ) $(BLOCK_OBJ) $(PLATFORM_OBJ) $(addprefix $(MODDIR)/,$(addsuffix .mod,$(COMMON_MODULES))) $(addprefix $(OFFLINE_MODDIR)/,$(addsuffix .mod,$(OFFLINE_MODULES))) $(addprefix $(BLOCK_MODDIR)/,$(addsuffix .mod,$(BLOCK_MODULES))) $(LIB) $(LIB).objects.rsp $(EXEC) $(BLOCK_EXEC) $(PROFILE_FILE)
clean: neat | $(BUILD_ROOT)
	$(file >$(BUILD_ROOT)/clean-files.list)
	$(foreach artifact,$(CLEAN_FILES),$(file >>$(BUILD_ROOT)/clean-files.list,$(artifact)))
	@cr=$$(printf '\r'); while IFS= read -r artifact; do artifact=$${artifact%$$cr}; $(RM) "$$artifact" || exit 1; done < "$(BUILD_ROOT)/clean-files.list"
	$(RM) "$(BUILD_ROOT)/clean-files.list"
