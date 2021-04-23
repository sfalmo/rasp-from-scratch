opts_soundingloc               = True
opts_soundingloc@txFont        = "helvetica"
opts_soundingloc@txFontColor   = 0  ;white
opts_soundingloc@txFontHeightF = 0.010
opts_soundingloc@txJust        = "CenterCenter"  ; should be default but make sure

skewtOpts                      = True
skewtOpts@units                = UNITS
skewtOpts@tiMainFontHeightF    = 0.001
;;; convert to pilot units (english)
if( UNITS .ne. "metric" ) then
   skewtOpts@DrawHeightScaleFt = True
else
   skewtOpts@DrawHeightScaleFt = False
end if

dataOpts                       = True
dataOpts@Parcel                = 0
dataOpts@WspdWdir              = False   ; wind speed and dir [else: u,v]
dataOpts@PlotWindH             = False  ; plot wind barbs at h lvls [pibal; special]
dataOpts@HspdHdir              = True   ; wind speed and dir [else: u,v]
dataOpts@units                 = UNITS

