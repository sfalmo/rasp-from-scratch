;; TO ALTER BL CROSS-SECTION PLOT SECTION
;; ALSO ALTERS BOXWMAX

;if( Region .eq. "UK2+1" .or. Region .eq. "UK+0") then
;    opts_w@ContourParameters = (/ -450., 450., 50. /)
;else
;    opts_w@ContourParameters = (/ -250., 250., 50. /)
;end if

if( Region .eq. "UK2+1" ) then
    opts_w@ContourParameters = (/ -450., 450., 50. /)
else
    opts_bparam@colorMap = "press26"
    opts_bparam@ContourParameters = (/ -300., 300., 25. /)
end if

; Adjust top level of boxwmax & xbl
; blsectionztop = 18 ; Kft (unless  UNITS are "metric")
; blsectionztop = 5  ; Km  (if UNITS are "metric")

if( Region .eq. "TIR" .or. Region .eq. "TEST5" ) then
    blsectionztop = 5  ; Km  (if UNITS are "metric")
else
    blsectionztop = 5  ; Km  (if UNITS are "metric")
end if

contourLines = "rh"

; Change horizontal extent of section
; span gewijzigd in plot.funcs.ncl, dat werkt wel
; span = 50 ; Km
  
; Select Contour Lines overlay
; contourLines = "thetac" ; Potential Temp (default)
; contourLines = "rh"     ; Relative Humidity

