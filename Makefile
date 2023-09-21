# Makefile for ITA TOOLBOX #24 tr

AS	= HAS.X -i $(INCLUDE)
LK	= hlk.x -x
CV      = -CV.X -r
CP      = cp
RM      = -rm -f

INCLUDE = $(HOME)/fish/include

DESTDIR   = A:/usr/ita
BACKUPDIR = B:/tr/1.0
RELEASE_ARCHIVE = TR10
RELEASE_FILES = MANIFEST README ../NOTICE ../DIRECTORY ../HUPAIR CHANGES tr.1 tr.x

EXTLIB = $(HOME)/fish/lib/ita.l

###

PROGRAM = tr.x

###

.PHONY: all clean clobber install release backup

.TERMINAL: *.h *.s

%.r : %.x	; $(CV) $<
%.x : %.o	; $(LK) $< $(EXTLIB)
%.o : %.s	; $(AS) $<

###

all:: $(PROGRAM)

clean::

clobber:: clean
	$(RM) *.bak *.$$* *.o *.x

###

$(PROGRAM) : $(INCLUDE)/doscall.h $(INCLUDE)/chrcode.h $(EXTLIB)

include ../Makefile.sub

###
