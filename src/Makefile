all:	rpidatv 

#CFLAGS	= -Wall -g -O2 -D DIGITHIN
# Legacy globals in headers rely on GCC's common-symbol behavior (GCC 10+ defaults to -fno-common).
CFLAGS	= -Wall -g -O2 -Wno-unused-variable -Wno-unused-function -fcommon
LDFLAGS	= -lm -lrt -lpthread 

TARGET_ARCH ?= $(shell $(CC) -dumpmachine)
ifneq ($(findstring aarch64,$(TARGET_ARCH))$(findstring x86_64,$(TARGET_ARCH)),)
DVBSENCO_SOURCE = dvbsenco8_portable.c
else
DVBSENCO_SOURCE = dvbsenco8.s
endif

dvbsenco8_tables.h: dvbsenco8.s generate_dvbsenco_tables.py
	python3 generate_dvbsenco_tables.py dvbsenco8.s $@

rpidatv : rpigpio.c rpidatv.c $(DVBSENCO_SOURCE) fec100.c mailbox.c rpidma.c raspberry_pi_revision.c $(if $(filter dvbsenco8_portable.c,$(DVBSENCO_SOURCE)),dvbsenco8_tables.h)
		$(CC) $(CFLAGS) -o rpidatv rpidatv.c rpigpio.c $(DVBSENCO_SOURCE) fec100.c mailbox.c rpidma.c raspberry_pi_revision.c $(LDFLAGS)


CFLAGS_MUX	= -Wall -g -O2 
LDFLAGS_MUX	= -lm -lrt -lpthread -L/libmpegts/libmpegts.o

muxests : muxests.c
	$(CC) $(CFLAGS_MUX) -o muxests muxests.c $(LDFLAGS_MUX) 

install:
	cp rpidatv ../bin/
	cp dt-blob.bin /boot/
	$(info !!! You should reboot if it is the first installation !!!)
clean:

	rm -f rpidatv rpidatv.o fec100.o dvbsenco8.o dvbsenco8_tables.h mailbox.o rpigpio.o rpidma.o
