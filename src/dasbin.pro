function dasbin, unit, row, column, yinterp, xinterp, fill

;+
; NAME:
;	DASBIN
;
; PURPOSE:
;	Given a *das* packet stream (:b0:) on a specified logical unit,
;	gather "x_y_z" (array of xyz triples) data and bin them into a
;	rectangular float array.
;	** THIS FUNCTION REQUIRES DAS PACKET TAGGED INPUT STREAM **
;
; CALLING SEQUENCE:
;	array = dasbin (unit, row, column, [yinterp], [xinterp], [fill])
;
; INPUTS:
;	UNIT:  opened input data stream logical unit.
;
;	ROW:  "giferator" data structure containing information about
;		"verticle" dimension size and scaling.
;
;	COLUMN:  "giferator" data structure containing information
;		about "horizontal" dimension size and scaling.
;
;	YINTERP:  (optional) either scalar value giving the verticle
;		range to interpolate across or a 2-element array giving
;		ranges corresponding to the row.ybottom and row.ytop
;		data coordinates with interpolated ranges between.
;		This specifies the allowed interpolation range in the
;		positive direction from the given data coordinate.
;		(default 0.0)
;
;	XINTERP:  (optional) like yinterp above, but for the horizontal
;		data coordinates. (default 0.0)
;
;	FILL:  data value to substitute in place of missing non-interpolated
;		value (default 0.0)
;
; OUTPUTS:
;	A floating-point array of binned and interpolated (as necessary)
;	data suitable for subsequent scaling and plotting as a spectrogram,
;	for example.  fltarr(nx,ny)
;
; RESTRICTIONS:
;
;	This is NOT TESTED.
;	Logarithmic handling needs to be checked.
;	Packet and non-packet handling needs to be generalized.
;
; EXAMPLE:
;
; PROCEDURE:
;
; REVISION HISTORY:
;	1998-11-05 adapted from xbin.pro by L. Granroth
;	1999-02-22 limit interpolation to 1/8 of available pixels  LJG
;                  hmmm . . . let's just limit to 12 pixels  LJG
;       2011-08-25 very rare floating point rounding condition fixed LJG
;	2012-11-29 accomodate little-endian platform  LJG
;
;-

on_error, 2

n = n_params()
if n lt 3 then $
  message, 'usage:  array = dasbin (unit, row, column, [yinterp], [xinterp], [fill])'
if n lt 4 then yinterp = 0.0
if n lt 5 then xinterp = 0.0
if n lt 6 then fill = 0.0

; calculate the number of y bins and scaling factors (NEED TO VERIFY LOG CODE)

ny     = row.jtop - row.jbottom
ymin   = row.ybottom
ymax   = row.ytop
if ymax le ymin then $
  message, 'dasbin ERROR: row ytop less than or equal to ybottom'
if row.log ne 0 then begin
  ymin = alog10 (ymin)
  ymax = alog10 (ymax)
endif
yrange = ymax - ymin
yscale = float (ny) / yrange
  
; calculate the number of x bins and scaling factors

nx     = column.iright - column.ileft
xmin   = column.xleft
xmax   = column.xright
if xmax le xmin then $
  message, 'ERROR: column xright less than or equal to xleft'
if column.log ne 0 then begin
  xmin = alog10 (xmin)
  xmax = alog10 (xmax)
endif
xrange = xmax - xmin
xscale = float (nx) / xrange

if (nx le 0) or (ny le 0) then $
  message, 'ERROR: nx or ny are less than or equal to zero'

; initialize working variables

asize = long (nx) * long (ny)
array = fltarr (asize) ; transposed for collecting data
num   = intarr (asize)
tagstring = string (':  :0000', format='(a8)')
bytetag = bytarr(4)
colon = byte (':')
colon = colon(0)
tag = string (':  :', format='(a4)')
lengthstring = string ('0000', format='(a4)')
b0tag = string (':b0:', format='(a4)')
pktsize = 0L
oldpktsize = 0L
nfloats = 0L
hastags = 0
havedata = 0

on_ioerror, bail

; currently x_tagged_y_scan has no tags and x_y_z has tags

readu, unit, bytetag
if (bytetag(0) eq colon) and (bytetag(3) eq colon) then begin
  hastags = 1
  tag = string (bytetag)
  readu, unit, lengthstring
  reads, lengthstring, oldpktsize, format='(z4)'
  nfloats = oldpktsize / 4
  buf = fltarr (nfloats, /nozero)
endif else begin
  hastags = 0
  x = float (bytetag, 0)
  byteorder, x, /lswap, /swap_if_little_endian
  buf = fltarr (ny, /nozero)
endelse

readu, unit, buf
byteorder, buf, /lswap, /swap_if_little_endian

; read in all data and sum into appropriate bins

on_ioerror, eof

if hastags ne 0 then begin

  while 1 do begin

    if (tag eq b0tag) then begin

      index = indgen(nfloats/3) * 3 ; point at x (time) values
      if column.log ne 0 then x = alog10(buf(index)) $
      else x = buf(index)

      index = index + 1 ; now pointing at y (frequency) values
      if row.log ne 0 then y = alog10(buf(index)) $
      else y = buf(index)

;     clip (select only the points within the binning array boundary)

      index = where((x ge xmin) and (x lt xmax) and $
                    (y ge ymin) and (y lt ymax), n)

      if n gt 0 then begin
;       map the data coordinates to bin indices
        x = long((x(index) - xmin) * xscale)
        y = long((y(index) - ymin) * yscale)
        idest = (x * ny + y) ; destination in linear (transposed) array
        index = index * 3 + 2 ; indices of the corresponding data in buf
;
;	We have to do the following loop to get overlapping items handled.
;	array(idest) = array(idest) + buf(index) doesn't work as expected
;
	if (idest(0) ge 0) and (idest(n-1) lt asize) then begin
	  for i = 0, n-1 do begin
	    array(idest(i)) = array(idest(i)) + buf(index(i)) ; ASSUME NO FILL DATA !!!
	    num(idest(i)) = num(idest(i)) + 1
	  endfor
	  havedata = 1
	endif
      endif

    endif ; tag eq ":b0:"

    readu, unit, tag
    readu, unit, lengthstring
    reads, lengthstring, pktsize, format='(z4)'
    if pktsize ne oldpktsize then begin
      nfloats = pktsize / 4
      buf = fltarr (nfloats, /nozero)
      oldpktsize = pktsize
    endif
    readu, unit, buf
    byteorder, buf, /lswap, /swap_if_little_endian

  endwhile

endif ; else begin ; no tags  NOT IMPLEMENTED YET !!!

;  while 1 do begin

;    if column.log ne 0 then x = (alog10(x) - xmin) * xscale
;    else x = (x - xmin) * xscale

;    readu, unit, x, yscan

;  endwhile

eof:
on_ioerror, null

; if there isn't any data, just return an "empty" array

if havedata eq 0 then return, replicate(fill, nx, ny)

; now average any bins with multiple samples

index = where (num gt 1, n)
if n gt 0 then array(index) = array(index) / num(index)

;------------------------------------------------------------------------
;
; And now . . . THE INERPOLATION !  (This is the fancy part)
;
;------------------------------------------------------------------------

; The interpolation parameters are either a scalar applying to the
; entire range or a two-element array applying to the min and max values
; and interpolated inbetween (i.e. interpolated interpolation ranges ;^)

if n_elements (xinterp) eq 1 then begin
  if (xinterp gt 0.0) and (column.log ne 0) then xinterp = alog10(xinterp)
  ax = replicate (xinterp, nx)
endif else begin
  xint = xinterp(0:1)
  if (xint(0) gt 0.0) and (xint(1) gt 0.0) and (column.log ne 0) then $
    xint = alog10(xint)
  ax = interpolate (xint, findgen(nx)/nx)
  ilimit = 12 ; ilimit = nx / 8
  xlimit = float(ilimit) / xscale + xmin
  for i = 0, nx-1 do begin
    if ax(i) gt xlimit then ax(i) = xlimit
  endfor
endelse

if n_elements (yinterp) eq 1 then begin
  if (yinterp gt 0.0) and (row.log ne 0) then yinterp = alog10(yinterp)
  ay = replicate (yinterp, ny)
endif else begin
  yint = yinterp(0:1)
  if (yint(0) gt 0.0) and (yint(1) gt 0.0) and (row.log ne 0) then $
    yint = alog10(yint)
  ay = interpolate (yint, findgen(ny)/ny)
  jlimit = 12 ; jlimit = ny / 8
  ylimit = float(jlimit) / yscale + ymin
  for j = 0, ny-1 do begin
    if ay(j) gt ylimit then ay(j) = ylimit
  endfor
endelse

; generate a lookup table for a half-cycle sine-weighted
; "rounded histogram" interpolation

table = (cos(findgen(100) * !pi / 100.0) + 1.0) / 2.0

; generate tables of data coordinates corresponding to grid locations

xcoord = findgen(nx) / xscale + xmin
ycoord = findgen(ny) / yscale + ymin

; get the data into a rectangular array (still transposed)

array = reform (array, ny, nx, /overwrite)
num = reform (num, ny, nx, /overwrite)

; now scan in the y direction, interpolating where appropriate
; (if anyone reading this can think of an "idl" way of avoiding the
; "for" loops, please let me know)

for i = 0, nx - 1 do begin ; each set of bins with a common x coordinate

  jzero = where (num(*,i) eq 0, nzero)
  if nzero gt 0 then array(jzero,i) = fill ; pre-fill missing data

  if (nzero gt 0) and (nzero lt ny-1) then begin ; partial data in this x bin
    jindex = where (num(*,i) ne 0, nj)
    jgaps = where ((jindex(1:*) - jindex(0:nj-2)) gt 1, ng)
    for ig = 0, ng - 1 do begin ; each gap
      jj = jgaps(ig)
      j0 = jindex(jj)
      j1 = jindex(jj+1)
      y0 = ycoord(j0)
      y1 = ycoord(j1)
      if (y1 - y0) le ay(j0) then begin ; gap is within interpolation range
        jrange = j1 - j0
	for j = j0 + 1, j1 - 1 do begin ; each bin in gap
	  weight = table ((j - j0) * 100 / jrange)
	  array(j,i) = array(j0,i) * weight + array(j1,i) * (1.0 - weight)
	endfor ; each bin in gap
      endif ; appropriate gap
    endfor ; each gap
  endif ; some missing and at least two data points      

endfor; each set of bins with a common x coordinate

; this is a good place to transpose the array

array = transpose (array)

; now scan in the x direction, interpolating where appropriate
; this is a little different because we will allow interpolation between
; data that were a result of interpolation in the other dimension

for j = 0, ny - 1 do begin ; each set of bins with a common y coordinate

  iindex = where (array(*,j) ne fill, ni)
  if ni gt 1 then begin ; at least two available data points
    igaps = where ((iindex(1:*) - iindex(0:ni-2)) gt 1, ng)
    for ig = 0, ng - 1 do begin ; each gap
      ii = igaps(ig)
      i0 = iindex(ii)
      i1 = iindex(ii+1)
      x0 = xcoord(i0)
      x1 = xcoord(i1)
      if (x1 - x0) le ax(i0) then begin ; gap is within interpolation range
        irange = i1 - i0
        for i = i0 + 1, i1 - 1 do begin ; each bin in gap
          weight = table ((i - i0) * 100 / irange)
	  array(i,j) = array(i0,j) * weight + array(i1,j) * (1.0 - weight)
        endfor; each bin in gap
      endif ; appropriate gap
    endfor ; each gap
  endif ; at least two available data points

endfor ; each set of bins with a common y coordinate

; if we're awfully lucky, then it all worked

!err = 0
return, array

; if there was an error reading the first record, here is where we bail out

bail:
message, 'ERROR: cannot read first record from input stream'

end
