# das1-giferator
Server-side graphics engine for The University of Iowa plasma wave group das (or das1 or das classic) system

## Giferator build/install notes

See make.note for more details.

### Setup

export PREFIX= place where you'd like to have the software installed,

export IDL_BIN= path to idl version to build against

export DAS_DATASETROOT= your prefered DSDF location

export DAS_TEMP= your prefered log file location

### Build/Install/Test

build:
gmake

install:
gmake install

test:
gmake test
kview build*/*.gif

### Usage

Giferator was designed as a CGI application for web servers, but it can also be
used as a command line tool:

1. Set the IDL_PATH
2. Cat commands to idl
3. rename batch.gif to what you'd like it to be.

See make.note for further details.
