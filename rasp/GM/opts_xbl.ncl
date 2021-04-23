;;; Options for W - Coloured contours

opts_w                             = True
opts_w@cnFillOn                    = True
opts_w@vpWidthF                    = 0.80
opts_w@vpXF                        = 0.10
opts_w@cnLinesOn                   = False
opts_w@tiMainOn                    = False
opts_w@vpYF                        = 0.90
opts_w@vpHeightF                   = 0.70
opts_w@tiXAxisFontHeightF          = 0.015
opts_w@tiYAxisFontHeightF          = 0.015
opts_w@tmXBLabelFontHeightF        = 0.015 ; tmLabel is for numbers
opts_w@tmYLLabelFontHeightF        = 0.015
opts_w@cnInfoLabelOn               = False
opts_w@tmYLLabelDeltaF             = -0.60 ; move y label to right, away from left border
opts_w@tmXBLabelDeltaF             = -0.5  ; move x label to top, away from bottom border

;;; For Label Bar (colorbar)
opts_w@lbAutoManage                = False
opts_w@lbLabelFont                 = "helvetica"   ; for numbers
opts_w@lbLabelFontHeightF          = 0.015
opts_w@lbTitleFontHeightF          = 0.015
opts_w@lbTitleFont                 = "helvetica"   ; for string

;;; Labelbar options to allow larger vertical plot - but _with_ title
; Hieronder labelbarheight gewijzigd van 0.05 naar 0.10:
opts_w@pmLabelBarHeightF           = 0.10 ;
opts_w@pmLabelBarWidthF            = 0.80 ;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Options for Title
ENV_NCL_ID = getenv("ENV_NCL_ID")
if ( .not. ismissing(ENV_NCL_ID) .and. ENV_NCL_ID .ne. "" ) then
        opts_w@TimeLabel = str_strip( ENV_NCL_ID )
else
        opts_w@TimeLabel = ""
end if
opts_w@LevelLabel = "Slice through lat,lon = " + lat + "," + lon + " @" + ang + "~F34~0~F21~"

if(contourLines .eq. "thetac") then
   opts_w@MainTitle  = "Wind-Parallel Section at Max W: Vertical Velocity & Pot.Temp. (~F34~0~F21~C)"
else
   opts_w@MainTitle  = "Wind-Parallel Section at Max W: Vertical Velocity & RH (%)"
end if

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Options for thetac / rh (contour lines - no titles/labels)
opts_var                           = True
opts_var@NoTitles                  = True
opts_var@cnLineLabelFontHeightF    = .004
opts_var@cnInfoLabelOn             = False
if(contourLines .eq. "thetac") then
    opts_var@ContourParameters     = (/ 0.,0., 1. /)
else	; contourLines = "rh"
    opts_var@ContourParameters     = (/ 10., 90., 10. /)
end if

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Options for cldfra overlay (stipple)
opts_cld                           = True
opts_cld@cnLinesOn                 = True; False
opts_cld@cnMonoLineThickness       = True
opts_cld@cnConstFLabelOn           = False
opts_cld@cnConstFEnableFill        = False
opts_cld@cnLineThicknessF          = 3
opts_cld@cnLineLabelsOn            = False
opts_cld@cnMonoFillPattern         = True
opts_cld@cnMonoFillColor           = True
opts_cld@MainTitle                 = ""
opts_cld@TimeLabel                 = ""
opts_cld@LevelLabel                = ""
opts_cld@UnitLabel                 = ""
opts_cld@pmLabelBarDisplayMode     = "NoCreate"
opts_cld@cnMonoFillPattern         = False
opts_cld@cnFillPatterns            = (/ -1, 17 /)
opts_cld@cnFillDotSizeF            = 4.0/1000.0
opts_cld@cnFillColor               = "black"
opts_cld@ContourParameters         = (/ 0.5, 0.5, 0.5 /)


