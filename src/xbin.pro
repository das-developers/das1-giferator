; 08-31-95 modified for 8-byte packet tag
; 03-04-96 modified to use packet tags only if one appears in the first read
; 2012-11-29 modified to accomodate little-endian platform  LJG

function xbin, unit, ny, column, xinterp, fill

on_error, 2

n = n_params()
if n lt 3 then $
  message, 'usage:  array = xbin (unit, ny, column, [xinterp], [fill])'
if n lt 4 then xinterp = 0.0
if n lt 5 then fill = 1.e-32

; calculate the number of x bins and scaling factors

nx     = column.iright - column.ileft
xmin   = column.xleft
xmax   = column.xright
xrange = xmax - xmin
xscale = float (nx) / xrange

; need to add log handling

array = fltarr (ny, nx) ; transposed for collecting data
yscan = fltarr (ny, /nozero)
num   = intarr (ny, nx)
tagstring = string (':  :0000', format='(a8)')
bytetag = bytarr(4)
colon = byte (':')
colon = colon(0)
tag = string (':  :', format='(a4)')
lengthstring = string ('0000', format='(a4)')
b0tag = string (':b0:', format='(a4)')
bxtag = string (':bx:', format='(a4)')
bytag = string (':by:', format='(a4)')
pktsize = 0L
hastags = 0

x = xmin

if (xmin lt xmax) then begin
  testmin = xmin
  testmax = xmax
endif else begin
  testmin = xmax
  testmax = xmin
endelse

testxscale = float (nx) / (testmax - testmin)

on_ioerror, bail

; readu, unit, tagstring
; print, tagstring
; reads, tagstring, tag, pktsize, format='(a4, z4)' ; should do something with this

readu, unit, bytetag
if (bytetag(0) eq colon) and (bytetag(3) eq colon) then begin
  hastags = 1
  tag = string (bytetag)
  readu, unit, lengthstring
endif else begin
  hastags = 0
  x = float (bytetag, 0)
  readu, unit, yscan
  byteorder, x, yscan, /lswap, /swap_if_little_endian
endelse

; read in all data and sum into appropriate bins

on_ioerror, eof
while 1 do begin

  if hastags then begin

    reads, lengthstring, pktsize, format='(z4)'

    case tag of

      ':bx:': begin
        xadjust = fltarr (pktsize / 4, /nozero);
	readu, unit, xadjust
        byteorder, xadjust, /lswap, /swap_if_little_endian
      end

      ':by:': begin
        ycoords = fltarr (pktsize / 4, /nozero);
	readu, unit, ycoords
        byteorder, ycoords, /lswap, /swap_if_little_endian
      end

      ':b0:': begin
        yscan = fltarr (pktsize / 4, /nozero);
	readu, unit, yscan
        byteorder, yscan, /lswap, /swap_if_little_endian
      end

    endcase

  endif

  if x ge testmin and x lt testmax then begin
    i = fix ((x - xmin) * xscale)
    array(*,i) = array(*,i) + yscan
    num(*,i) = num(*,i) + (yscan ne 0.0) ; maybe should use fill value
  endif

;   readu, unit, tagstring
;   print, tagstring
;   reads, tagstring, tag, pktsize, format='(a4, z4)'
  readu, unit, x, yscan
  byteorder, x, yscan, /lswap, /swap_if_little_endian

endwhile
eof:
on_ioerror, null

; average as necessary and interpolate if requested

interp = fix (xinterp * xscale + 1.0)
testinterp = fix (xinterp * testxscale + 1.0)
i0  = -32000
nz0 = 0

for i = 0, nx - 1 do begin
  iz = where (num(*,i) eq 0, nz)
  if nz gt 0 then array(iz,i) = fill
  index = where (num(*,i), n)
  if n gt 0 then begin
    array(index,i) = array(index,i) / num(index,i)
    igap = i - i0
    if igap gt 1 and igap le testinterp then begin
      if nz0 gt 0 then array(iz0, i0) = array(iz0, i)
      if nz  gt 0 then array(iz,  i)  = array(iz, i0)
      delta = !pi / float (igap)
      for ii = i0 + 1, i - 1 do begin
        weight = (cos (float(ii - i0) * delta) + 1.0) / 2.0
	array(*,ii) = array(*,i0) * weight + array(*,i) * (1.0 - weight)
      endfor
    endif
    i0  = i
    nz0 = nz
    iz0 = iz
  endif
endfor

!err = 0
return, transpose (array)
bail:
!err = 1
return, replicate (fill, nx, ny)

end
