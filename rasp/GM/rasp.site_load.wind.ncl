;;; TO ALTER WIND PLOT SECTION

; Constrain SfcWind (10m) *only* to 0-26 Kt in 2 Kt steps
;if(plot_param .eq. "sfcwind" ) then
;	opts_ws@ContourParameters = (/ 2., 24., 2. /);
;end if

; Constrain SfcWind0 (2m) *only* to 0-18 Kt in 2 Kt steps
;if(plot_param .eq. "sfcwind0" ) then
;	opts_ws@ContourParameters = (/ 2., 16., 2. /);
;end if

if( plot_param .eq. "sfcwind0" ) then
    opts_ws@ContourParameters = (/ 2., 30., 2. /)
end if
if( plot_param .eq. "sfcwind" ) then
    opts_ws@ContourParameters = (/ 2., 30., 2. /)
end if
if( plot_param .eq. "sfcwind2" ) then
    opts_ws@ContourParameters = (/ 2., 30., 2. /)
end if
if( plot_param .eq. "bltopwind" ) then
    opts_ws@ContourParameters = (/ 2., 30., 2. /)
end if
if( plot_param .eq. "blwind" ) then
    opts_ws@ContourParameters = (/ 2., 30., 2. /)
end if

