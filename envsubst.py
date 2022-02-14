#!/usr/bin/env python3

import os
import sys


perr = sys.stderr.write

def prn_help():
	perr("\n")
	perr("Substitute named string format items in a file with values from the\n")
	perr("environment.\n")
	perr("\n")
	perr("Usage: %s INFILE OUTFILE\n"%os.path.basename(sys.argv[0]))
	perr("\n")
	
if len(sys.argv) < 3:
	prn_help()
	sys.exit(13)

fIn = open(sys.argv[1], 'r')
fOut = open(sys.argv[2], 'w')

sFmt = fIn.read()
fIn.close()

fOut.write(sFmt%os.environ)

fOut.close()

sys.exit(0)

