CONNECTALDIR ?= /home/sk/Desktop/MIT2.0/sk-host/Lab/6.175lab5/connectal

export BLUESPECDIR = /home/sk/Desktop/MIT-tools/bsc/bsc-2025.07-ubuntu-22.04/lib
export BSC = /home/sk/Desktop/MIT-tools/bsc/bsc-2025.07-ubuntu-22.04/bin/bsc
export PATH := /home/sk/Desktop/MIT-tools/bsc/bsc-2025.07-ubuntu-22.04/bin:$(PATH)

# BSC 编译标志
BSC_LIB_PATHS = \
    -p +:$(BLUESPECDIR)/Libraries \
    -p +:$(BLUESPECDIR)/Libraries/FPGA \
    -p +:$(BLUESPECDIR)/Libraries/FPGA/Xilinx

BSC_FLAGS = $(BSC_LIB_PATHS) \
    -show-range-conflict \
    -steps-warn-interval 100000 \
    -no-show-timestamps \
    -aggressive-conditions

S2H_INTERFACES = \
	ConnectalProcRequest:ConnectalWrapper.connectProc
H2S_INTERFACES = \
	ConnectalWrapper:ConnectalProcIndication
BSVFILES += \
	src/includes/Ifc.bsv
BSVPATH += / \
	src/ \
	src/includes \
	$(CONNECTALDIR)/bsv
CPPFILES += \
	main.cpp

USE_BUILDCACHE=1

#CONNECTALFLAGS += --mainclockperiod=20
#CONNECTALFLAGS += --verilog=ddr3_v2_0/
SOFTWARE_SOCKET_NAME=/tmp/connectal$(USER)
export SOFTWARE_SOCKET_NAME
CONNECTALFLAGS += -D $(VPROC)
CONNECTALFLAGS += --bscflags " -D $(VPROC) -steps-max-intervals 50 +RTS -K256M -RTS"
CONNECTALFLAGS += --bscflags " -show-schedule"
#CONNECTALFLAGS += --cxxflags="-g -std=gnu++11"

include $(CONNECTALDIR)/Makefile.connectal


clean:
	rm -rf bluesim


simple_compile:
	mkdir -p buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -p +:src/includes/ -aggressive-conditions -keep-fires src/TwoStageBTB.bsv
	
