PRO GIFOUT, IMG, R, G, B
;+
; NAME:
;       GIFOUT
;
; PURPOSE:
;	Write an IDL image and color table vectors in GIF format to
;	IDL unit -1 (stdout) (This is a modified WRITE_GIF.)
;	Special version works with PRINT, instead of WRITEU
;	for use with 7-minute demo mode
;
; CATEGORY:
;
; CALLING SEQUENCE:
;
;	GIFOUT, Image  ;Write a given array.
;
;	GIFOUT, Image, R, G, B  ;Write array with given color tables.
;
;
; INPUTS:
;	Image:	The 2D array to be output.
;
; OPTIONAL INPUT PARAMETERS:
;      R, G, B:	The Red, Green, and Blue color vectors to be written
;		with Image.
; KEYWORD PARAMETERS:
;	None.
;
; OUTPUTS:
;	If R, G, B values are not provided, the last color table
;	established using LOADCT is saved. The table is padded to
;	256 entries. If LOADCT has never been called, we call it with
;	the gray scale entry.
;
;
; COMMON BLOCKS:
;	COLORS
;
; SIDE EFFECTS:
;	If R, G, and B aren't supplied and LOADCT hasn't been called yet,
;	this routine uses LOADCT to load the B/W tables.
;
; RESTRICTIONS:
;	This routine only writes 8-bit deep GIF files of the standard
;	type: (non-interlaced, global colormap, 1 image, no local colormap)
;
; MODIFICATION HISTORY:
;	Written 9 June 1992, JWG.
;-
; Copyright (c) 1992, Research Systems, Inc.  All rights reserved.
;	Unauthorized reproduction prohibited.
;
COMMON colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr

; Check the arguments
ON_ERROR, 1		;Return to main level if error
n_params = N_PARAMS();

IF ((n_params NE 1) AND (n_params NE 4))THEN $
  message, "usage: GIFOUT, image, [r, g, b]'

; Is the image a 2-D array of bytes?

img_size	= SIZE(img)
IF img_size(0) NE 2 OR img_size(3) NE 1 THEN	$
	message, 'Image must be a byte matrix.'

cols	= img_size(1)
rows	= img_size(2)

; If any color vectors are supplied, do they have right attributes ?
IF (n_params EQ 1) THEN BEGIN
	IF (n_elements(r_curr) EQ 0) THEN LOADCT, 0	; Load B/W tables
	r	= r_curr
	g	= g_curr
	b	= b_curr
ENDIF

r_size	= SIZE(r)
g_size	= SIZE(g)
b_size	= SIZE(b)
IF ((r_size(0) + g_size(0) + b_size(0)) NE 3) THEN $
	message, "R, G, & B must all be 1D vectors."
IF ((r_size(1) NE g_size(1)) OR (r_size(1) NE b_size(1)) ) THEN $
	message, "R, G, & B must all have the same length."

;	Pad color arrays

clrmap	= BYTARR(3,256)

tbl_size		= r_size(1)-1
clrmap(0,0:tbl_size)	= r
clrmap(0,tbl_size:*)	= r(tbl_size)
clrmap(1,0:tbl_size)	= g
clrmap(1,tbl_size:*)	= g(tbl_size)
clrmap(2,0:tbl_size)	= b
clrmap(2,tbl_size:*)	= b(tbl_size)

hdr = [byte('GIF87a'),0b,0b,0b,0b,247b,0b,0b]
hdr(6) = cols AND 255
hdr(7) = cols / 256
hdr(8) = rows AND 255
hdr(9) = rows / 256

ihdr = [44b,0b,0b,0b,0b,hdr(6),hdr(7),hdr(8),hdr(9),7b]

on_ioerror, abort

writeu, -1, hdr, clrmap, ihdr		; this works, but not in demo mode

; print doesn't work because it refuses to emit a null (0)

;print, string(hdr), format='(a13,$)'
;for i = 0, 255 do print, string(clrmap(*,i)), format='(a3,$)'
;print, string(ihdr), format='(a10,$)'

ENCODE_GIF, -1, img

on_ioerror, null
return

abort: exit

END
