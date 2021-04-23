;;; TO ALTER CONTOUR PARAMETER PLOT SECTION

;;; example of altering wstar parameter contour interval/coloring
;;; (for more details see "Change plot formatting" section at http://www.drjack.info/twiki/bin/view/RASPop/ProgramUserChanges
;;example:  if( plot_param .eq. "wstar" ) then
  ;;example=fixed_colors:  opts_bparam@ContourParameters = (/ 100., 800., 100. /)
  ;;example=autoset_colors:  opts_bparam@ContourParameters = (/ 0., 0., 0. /)
  ;;example=autoset_colors:  delete( opts_bparam@ContourParameters )
;;example:  end if

;;;; PAULS ;;;;


; If plotting takes a LOOONGG time, try this
if( isvar("Region")) then
  if( Region .eq. "UK2+1" .or. Region .eq. "UK2" ) then
    opts_plot@cnFillMode = "MeshFill"
  else
    opts_plot@cnFillMode = "AreaFill"
  end if
end if

if( plot_param .eq. "pfd_tot" ) then
    opts_bparam@colorMap = "pfd"
   opts_bparam@ContourParameters = (/ 100., 900., 100. /)    
end if

if( plot_param .eq. "rain1" ) then
  ; opts_bparam@ContourParameters = (/ 0.1, 4.9, 0.1 /)
  ; opts_bparam@ExplicitLevels = (/ 0.0, 0.1, 0.33, 0.5, 0.75, 1.0, 3.30, 5.0, 7.50, 10.0 /)
   opts_bparam@ExplicitLevels = (/ 0.0, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0 /)
  ; opts_cn@ExplicitLevels = (/ 0.0, 0.1, 0.33, 0.5, 0.75, 1.0, 3.30, 5.0, 7.50, 10.0 /)
end if

;if( plot_param .eq. "wstar_bsratio" ) then
;  opts_bparam@ContourParameters = (/ 175., 575., 25. /)
;end if

;if( plot_param .eq. "wstar" ) then
;  opts_bparam@ContourParameters = (/ 0., 500., 25. /)
;end if

;;; Thermiek sterkte en B/S ratio
if( plot_param .eq. "wstar" ) then
    opts_bparam@ContourParameters = (/ 25., 500., 25. /)    
end if
if( plot_param .eq. "wstar_bsratio" ) then
    opts_bparam@ContourParameters = (/ 25., 500., 25. /)
end if
if( plot_param .eq. "bsratio" ) then
    opts_bparam@ContourParameters = (/ 1., 9., 1. /)
end if

;;; Grenslaag hoogte/dikte en variatie
if( plot_param .eq. "hwcrit" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "dwcrit" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "hglider" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "hbl" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "dbl" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "bltopvariab" ) then
    opts_bparam@ContourParameters = (/ 100., 2000., 100. /)
end if

;;; Wolk hoogte/potentieel
if( plot_param .eq. "zsfclcl" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "zsfclclmask" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "zblcl" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "zblclmask" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "blcwbase" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if

;;; Nog nagaan of deze wel positief kunnen zijn, anders legenda aanpassen
;legenda voor zsfclcldif en zblcldif vergelijkbaar met rain1 vastgelegd in rasp.bparam_resources.ncl
if( plot_param .eq. "zsfclcldif" ) then
    opts_bparam@ContourParameters = (/ -2000., 2000., 200. /)
end if
if( plot_param .eq. "zblcldif" ) then
    opts_bparam@ContourParameters = (/ -2000., 2000., 200. /)
end if

;;; Convergentie
if( plot_param .eq. "wblmaxmin" ) then
    opts_bparam@colorMap = "press26"
    opts_bparam@ContourParameters = (/ -300., 300., 25. /)
end if
if( plot_param .eq. "zwblmaxmin" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if

;;; Percentages
if( plot_param .eq. "blcloudpct" ) then
    opts_bparam@ContourParameters = (/ 5., 95., 5. /)
end if
if( plot_param .eq. "sfcsunpct" ) then
    opts_bparam@ContourParameters = (/ 5., 95., 5. /)
end if

;;; Wind snelheden
;;; Misschien nog kleinere intervallen bepalen afhankelijk van resultaten
if( plot_param .eq. "blwindshear" ) then
    opts_bparam@ContourParameters = (/ 2., 30., 2. /)
end if


if( plot_param .eq. "mslpress" ) then
    ;;; alleen interval bepaald, geen min/max
    opts_bparam@ContourParameters = (/ 0., 0., 1. /)
end if

;;; Temperaturen
if( plot_param .eq. "sfctemp" ) then
    ;;; alleen interval bepaald, geen min/max
    opts_bparam@ContourParameters = (/ 0., 0., 1. /)
end if
if( plot_param .eq. "sfcdewpt" ) then
    ;;; alleen interval bepaald, geen min/max
    opts_bparam@ContourParameters = (/ 0., 0., 1. /)
end if


if( plot_param .eq. "experimental1" ) then
    opts_bparam@ContourParameters = (/ 200., 3000., 200. /)
end if
if( plot_param .eq. "ter" ) then
    opts_bparam@ContourParameters = (/ 0., 0., 10. /)    
end if
if( plot_param .eq. "wstar175" ) then
    opts_bparam@ContourParameters = (/ 25., 500., 25. /)    
end if
if( plot_param .eq. "wrf=HGT" ) then
    opts_bparam@ContourParameters = (/ 0., 0., 10. /)
    opts_bparam@cnFillOn = True            
    opts_bparam@cnFillMode = "CellFill" 
    opts_bparam@cnCellFillEdgeColor = 1    
end if

