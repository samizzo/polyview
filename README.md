### PolyView 1.3b - Unreleased ANSI viewer
==========================================

This is the Turbo Pascal 7 source to PolyView, an unreleased (as far as I recall) MS-DOS
ANSI/RIP viewer that I wrote for the Melbourne, Australia-based polyester art group, which
I was a member of briefly. I can't find any releases that included this viewer, and the
1998/99 polyester releases include a different Polyview which was written by Grant Passmore,
aka skaboy / ACiD Productions, apparently as a favor/under contract to rippa, the founder
of Polyester.

I had somehow been hooked up with rippa and asked to build the viewer and join polyester.
I don't recall why my version was never used though, and I'm not listed as a member of
polyester in any releases as far as I can tell, so maybe there was a falling out. polyester
seem to have stopped releasing art packs around 1999 anyway.

There is a prebuilt binary in the BIN directory.

Building
--------

Use COMPILE.BAT to compile the sources. The batch file expects TP to be installed in:

	c:\dev\dos\tp

Adjust this in COMPILE.BAT as appropriate. The code will build into the BIN subdirectory.

The OBJ directory contains various precompiled files that are linked in (fonts, Turbo
Pascal's, EGA/VGA driver, the ANSI screen).

Unfortunately I couldn't find the source for P_SAUCE.TPU. I'm unsure why it's missing. This
is the unit that deals with reading the [SAUCE](https://github.com/radman1/sauce) information
from a file.

I've included CL-STWR1.ANS, an ANSI my good friend Clef made for my BBS (which I never ended
up actually running). Just so you have something to test it with!
