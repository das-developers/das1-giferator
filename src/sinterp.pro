function sinterp, data, zcoords, nz, zmin, zmax, zlimit, fill

;+
; NAME:
;	SINTERP
;
; PURPOSE:
;	Given an input array DATA and a one-dimensional array ZCOORDS containing
;	coordinates for the last (slowest varying) dimension of the data
;	array, interpolate values at NZ regularly spaced coordinates in
;	the interval [ZMIN ... ZMAX) using a half-cycle sine wave weighting.
;	This results in a smoothed histogram effect.  Gaps larger than ZLIMIT
;	are not interpolated.  Fill data may be specified in FILL.
;
; CALLING SEQUENCE:
;	result = sinterp (data, zcoords, nz, zmin, zmax [, zlimit [, fill]])
;
; INPUTS:
;	DATA:  array containing data samples.
;
;	ZCOORDS:  array containing coordinates of last dimension of DATA.
;	  This must have the same number of elements as that dimension.
;
;	NZ:  size of the last dimension of the output array.  This is the
;	  number of evenly-spaced coordinates for which an interpolation
;	  is calculated
;
;	ZMIN:  coordinate corresponding to the first element of the last
;	  dimension of the output array.  This is the minimum coordinate
;	  to calculate an interpolation for.
;
;	ZMAX:  coordinate corresponding to one past the last element of the
;	  last dimension of the output array.  Thus, for example, to specify
;	  an interval of one day in hours, ZMIN = 00 and ZMAX = 24, rather
;	  than 23 plus some ill-determined fraction depending on NZ.
;
;	ZLIMIT:  (optional) gaps in input data coordinates greater than
;	  ZLIMIT will not be interpolated across.  By default all gaps are
;	  interpolated across.
;
;	FILL:  (optional) value used to fill output array where interpolation
;	  is not performed (such as edges or large gaps).  By default floating
;	  zero is used.
;
; OUTPUTS:
;	A floating-point array of the same number of dimensions as DATA,
;	but with its last dimension equal to NZ.  The contents of the array
;	are the samples in DATA (at coordinates ZCOORDS) interpolated to new
;	evenly-spaced coordinates in the interval Z, ZMIN <= Z < ZMAX.
;
; SIDE EFFECTS:
;	none
;
; RESTRICTIONS:
;	ZCOORDS must be sorted in ascending order.  ZMIN must be less than
;	ZMAX.  The NZ new coordinates are obtained by a linear interpolation
;	between ZMIN and ZMAX.
;
; EXAMPLE:
;
; PROCEDURE:
;
; REVISION HISTORY:
;	Dec. 1993  Written by L. Granroth (larry-granroth@uiowa.edu)
;	Feb. 1997  removed "help" command from error conditions.  LJG
;-

on_error, 2

if n_params() lt 5 or n_params() gt 7 then $
  message, 'usage:  result = sinterp (data, zcoords, nz, zmin, zmax, [, zlimit [, fill]])'

s = size (data)
ncoords = n_elements (zcoords)
if s(0) lt 1 then message, 'missing or invalid data array'
if s(s(0)) ne ncoords then message, 'data dimension does not match coordinates'
if zmin ge zmax then message, 'zmin ge zmax'
if nz lt 1 then message, 'invalid output dimensions'
;  help, data, zcoords, nz, zmin, zmax
;  message, 'invalid arguments (data, zcoords, nz, zmin, zmax)'

; determine size of data chunk indexed by last dimension

chunk = 1L
for i = 1, s(0)-1 do chunk = chunk * s(i)

if n_params() lt 7 then zfill = fltarr (chunk) $
else if n_elements (fill) eq 1 then zfill = replicate (fill, chunk) $
else if n_elements (fill) eq chunk then zfill = fill $
else begin
;  help, fill
  message, 'invalid fill array'
endelse

if n_params() lt 6 then zlimit = 0

; initialize output array

result = fltarr (chunk, nz)

zscale = (zmax - zmin) / float (nz)

i0   = 0
i1   = 1
z0   = zcoords(i0)
z1   = zcoords(i1)
zgap = z1 - z0
if zgap gt 0.0 and (zlimit eq 0 or zgap lt zlimit) then $
  delta = !pi / zgap else delta = 0.0

j0 = chunk * i0
j1 = chunk * i1
d0 = data(j0:j0+chunk-1)
d1 = data(j1:j1+chunk-1)

; first fill in up to the first available sample

i = 0
z = zmin
while z lt z0 and i lt nz do begin
  result(*,i) = zfill
  i = i + 1
  z = float (i) * zscale + zmin
endwhile

; now generate interpolated data where bounding samples are available

while z le zcoords(ncoords-1) and i lt nz do begin

; update the bounding data sample coordinates if necessary

  while z gt z1 and i1 lt ncoords-1 do begin
    i1 = i1 + 1
    i0 = i0 + 1
    z0 = zcoords(i0)
    z1 = zcoords(i1)
    if z le z1 then begin
      j0 = chunk * i0
      j1 = chunk * i1
      d0 = data(j0:j0+chunk-1)
      d1 = data(j1:j1+chunk-1)
      zgap = z1 - z0
      if zgap gt 0.0 and (zlimit eq 0 or zgap lt zlimit) then $
        delta = !pi / zgap else delta = 0.0
    endif
  endwhile

  if delta gt 0.0 then begin
    if z ge z1 then weight = 0.0 $
    else weight = (cos ((z - z0) * delta) + 1.0) / 2.0
    result (*,i) = d0 * weight + d1 * (1.0 - weight)
  endif else result(*,i) = zfill

  i = i + 1
  z = float (i) * zscale + zmin

endwhile

; finally fill any trailing space

while i lt nz do begin
  result(*,i) = zfill
  i = i + 1
endwhile

; reformat the result array

s(s(0)) = nz
return, reform (result, s(1:s(0)), /overwrite)
end
