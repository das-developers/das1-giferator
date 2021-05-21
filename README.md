# das1-giferator
Server-side graphics engine for The University of Iowa plasma wave group das (or das1 or das classic) system

Giferator utilizes the [L3Harris IDL language](https://www.l3harrisgeospatial.com/Software-Technology/IDL).
It was initially designed as a CGI application for web servers such that HTML forms could specify datasets,
detailed plot layout, readers, and reader parameters.  The plot generator can also be used in scripts that specify
the sequence of high-level configuration commands and instructions for the IDL program to execute to generate plot files.

## Giferator build/install notes

See make.note for more details.

### Setup

export PREFIX= installation home, like /usr/local or /home/sue

export IDL_BIN= path to idl version to build against

export DAS_DATASETROOT= your prefered DSDF location

export DAS_TEMP= your prefered log file location

### Build/Install/Test

1. gmake
2. gmake install
3. gmake test
4. display build*/*.gif

### Usage

Giferator was designed as a CGI application for web servers, but it can also be
used as a command line tool:

1. Set the IDL_PATH
2. Cat commands to idl
3. rename batch.gif to what you'd like it to be.

See make.note for further details.
