##############################################################################
# Generics

# Use GNU make 
ifneq ($(MAKE),gmake)
$(error This make file is intended for use with gmake)
endif

ifndef IDL_BIN
$(error Define IDL_BIN before building the giferator)
endif

# Pick a default installed locations, if user doesn't have them defiend
ifeq ($(PREFIX),)
PREFIX=$(HOME)
endif

# Pick defaults for das integration, to autofind the dsdfs already setup
# by Larry and Co, set DAS_DATASETROOT=/home/Web/das/datasetroot
ifeq ($(DAS_DATASETROOT),)
DAS_DATASETROOT=$(PREFIX)/datasetroot
endif

# The old giferator used: /home/Web/tmp
ifeq ($(DAS_TEMP),)
DAS_TEMP=$(PREFIX)/tmp
endif

ifndef INST_BIN
INST_BIN=$(PREFIX)/bin
endif

IDL_OS:=$(shell echo 'print, !version.os' | $(IDL_BIN) 2>/dev/null)
IDL_OS:=$(strip $(IDL_OS))

IDL_ARCH:=$(shell echo 'print, !version.arch' | $(IDL_BIN) 2>/dev/null)
IDL_ARCH:=$(strip $(IDL_ARCH))

IDL_WORDSZ:=$(shell echo 'print, !version.memory_bits' | $(IDL_BIN) 2>/dev/null)
IDL_WORDSZ:=$(strip $(IDL_WORDSZ))

IDL_RELEASE:=$(shell echo 'print, !version.release' | $(IDL_BIN) 2>/dev/null)
IDL_RELEASE:=$(strip $(IDL_RELEASE))

# Set wordsz to 32 if not defined
ifeq ("$(IDL_WORDSZ)","")
IDL_WORDSZ:=32
endif

# Okay, now set the library directory
ifndef INST_IDLLIB
ifeq ("$(IDL_WORDSZ)","64")
INST_IDLLIB=$(PREFIX)/lib/sparcv9/idl$(IDL_RELEASE)
CC_WORDFLG=-m64
else
INST_IDLLIB=$(PREFIX)/lib/idl$(IDL_RELEASE)
CC_WORDFLG=-m32
endif
endif

BUILD_DIR=build-$(IDL_RELEASE)-$(IDL_OS).$(IDL_ARCH).$(IDL_WORDSZ)

export DAS_DATASETROOT
export DAS_TEMP
export INST_IDLLIB


##############################################################################

CC=cc

# Sharable objects for use with RSI/IDL CALL_EXTERNAL
CFLAGS= $(CC_WORDFLG) -O -G -KPIC -fsingle

##############################################################################

# Source order is IMPORTANT!  List dependencies of the main program first
#IDL_SRCS=nearest.pro makex.pro jd2date.pro monthnames.pro weekday.pro dt_tm_mak.pro \
#  dt_tm_inc.pro gifout.pro tnaxes.pro date2ymd.pro dt_tm_brk.pro inrange.pro \
#  jd2ymd.pro ymd2jd.pro stress.pro strep.pro sechms.pro xbin.pro sinterp.pro \
#  giferator.pro
  
IDL_SRCS= date2ymd.pro delchr.pro fndwrd.pro getwrd.pro gifout.pro nearest.pro \
 inrange.pro isnumber.pro jd2ymd.pro js2ymds.pro makex.pro makexy.pro \
 monthnames.pro nthweekday.pro nwrds.pro repchr.pro sechms.pro secstr.pro \
 sinterp.pro strep.pro stress.pro strsub.pro tnaxes.pro weekday.pro xbin.pro \
 dt_tm_mak.pro dt_tm_fromjs.pro ymd2date.pro jd2date.pro ymd2jd.pro ymds2js.pro \
 dt_tm_brk.pro dt_tm_inc.pro \
 dasbin.pro giferator.pro

IDL_SRCS_IN=$(patsubst %.pro,src/%.pro,$(IDL_SRCS))
IDL_SRCS_BLD=$(patsubst %.pro,$(BUILD_DIR)/%.pro,$(IDL_SRCS))

DSDFS=color_wedge.dsdf


PWD=$(shell pwd)

##############################################################################
# pattern rules targets

$(BUILD_DIR)/%.pro:src/%.pro.in | $(BUILD_DIR)
	./envsubst.py $< $@
	chmod +x $@
	
$(BUILD_DIR)/%.pro:src/%.pro | $(BUILD_DIR)
	cp $< $@
	chmod +x $@

$(INST_IDLLIB)/%.pro:$(BUILD_DIR)/%.pro
	install -D -m 664 $< $@

##############################################################################
# Explicit targets

.PHONY : test install

build: $(BUILD_DIR)  $(BUILD_DIR)/giferator.sav $(BUILD_DIR)/ljgidl.so

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

$(BUILD_DIR)/giferator.sav:$(IDL_SRCS_BLD)
	@if [ -f $(BUILD_DIR)/compile.cmd ]; then rm $(BUILD_DIR)/compile.cmd; fi
	@#for file in $(IDL_SRCS_BLD); do echo ".compile $$file" >> $(BUILD_DIR)/compile.cmd; done
	@echo ".compile giferator.pro" >> $(BUILD_DIR)/compile.cmd
	@printf "resolve_all\nsave,/routines,file='giferator.sav'\n" >> $(BUILD_DIR)/compile.cmd
	@echo
	cd $(BUILD_DIR) && (cat compile.cmd | $(IDL_BIN))
	
$(BUILD_DIR)/ljgidl.so:src/ljgidl.c
	$(CC) $(CFLAGS) $< -o $@


install: build $(INST_IDLLIB)/giferator.pro $(INST_IDLLIB)/giferator.sav \
         $(INST_IDLLIB)/ljgidl.so $(DAS_DATASETROOT)/color_wedge.dsdf
			
$(DAS_DATASETROOT)/color_wedge.dsdf:test/color_wedge.dsdf
	install -D -m 664 $< $@

$(INST_IDLLIB)/giferator.sav:$(BUILD_DIR)/giferator.sav
	install -D -m 664 $< $@

$(INST_IDLLIB)/ljgidl.so:$(BUILD_DIR)/ljgidl.so
	install -D -m 775 $< $@

test: install $(BUILD_DIR)/gll-wideband_1997-05-06_1300_1510.gif

$(BUILD_DIR)/gll-wideband_1997-05-06_1300_1510.gif:
	@if [ -f $(BUILD_DIR)/batch.gif ]; then rm -f $(BUILD_DIR)/batch.gif; fi
	@echo "Test1: gll-wideband_1997-05-06_1300_1510"
	@cd $(BUILD_DIR) && cat ../test/gll-wideband_1997-05-06_1300_1510.cmd | \
	    env DAS_DATASETROOT=$(PWD)/test IDL_PATH="<IDL_DEFAULT>:$(INST_IDLLIB)/giferator" $(IDL_BIN)
	@if [ -f $(BUILD_DIR)/batch.gif ]; then \
	  mv $(BUILD_DIR)/batch.gif $@; \
	  echo "Test1 may have worked"; \
	else \
	  echo "Test1 Failed"; \
	  exit 1; \
	fi

clean:
	rm -r $(BUILD_DIR)/*.pro $(BUILD_DIR)/compile.cmd $(BUILD_DIR)/*.sav $(BUILD_DIR)/*.gif

distclean:
	rm -r $(BUILD_DIR)
