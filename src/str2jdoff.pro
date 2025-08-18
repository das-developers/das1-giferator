function str2jdoff timestr, jd, off

;+
; NAME:
;       STR2JDOFF
;
; PURPOSE:
;       Given a string representation of time, use PARSETIME.PRO to parse
;       time components and return the Julian date and offset into the UT
;       day in double precision seconds.
;
; CATEGORY:
;       Time handling
;
; CALLING SEQUENCE:
;       result = str2jdoff (timestr, jd, off)
;
; INPUTS:
;       timestr: string time representation
;
; OUTPUTS:
;       result: 0 = failure; 1 = success (for compatibility with older version)
;       jd: long int Julian date (at noon of the UT date)
;       off: double precision second of the UT day
;
; RESTRICTIONS:
;       See PARSETIME restrictions.
;
; MODIFICATION HISTORY:
;       Written by L.J. Granroth, 2025-08-17
;       to replace the call_external version compiled from C
;-

  if n_params() lt 3 then begin
    message, 'Usage: result = str2jdoff (timestr, jd, off)'
    return 0
  endif

  if not parsetime(timestr, year, month, day_month, day_year, hour, minute, second) then $         return 0

  jd = 367L * year - 7L * (year + (month + 9L) / 12L) / 4L - $
       3L * ((year + (month - 9L) / 7L) / 100L + 1L) / 4L + $
       275L * month / 9L + day_month + 1721029L

  off = second + double(minute) * 60.0 + double(hour) * 3600.0

  return 1

end
