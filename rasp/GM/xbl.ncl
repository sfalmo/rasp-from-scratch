;;;        BL CROSS-SECTION PLOT SECTION

   if( ( name_max .ge. 2 .and. name_chars(0:2) .eq. "xbl" ) .or. ( name_max .eq. 6 .and. name_chars(0:6) .eq. "boxwmax" ) ) then
      lplotdone = 1
      ldoblsection = 1
      ldowautosection = 0
      print ( "    DOING BL SECTION PLOT" )

     ;;; --------------------------------------------------------------------------------
     ;;; START OF EXTRACTION OF X,Y,ANGLE FROM PARAMETER NAME
     if( name_max .ge. 2 .and. name_chars(0:2) .eq. "xbl" ) then
       mapangledeg = default_mapangledeg
       xofblsection = default_xofblsection   ; note this is 0 based
       yofblsection = default_yofblsection   ; note this is 0 based
       if( name_max .gt. 2 ) then
         xfield = extract_string_field( PARAMS(iparam), 2, "_" )
         if ( xfield .ne. "" ) then
           xofblsection = stringtofloat(xfield)   ; note this is 0 based
         end if
         yfield = extract_string_field( PARAMS(iparam), 3, "_" )
         if ( xfield .ne. "" ) then
           yofblsection = stringtofloat(yfield)   ; note this is 0 based
         end if
         ;;; if either x or y field contains a decimalpt assume both are long,lat
         if ( string_pattern_grep( xfield,"." ) .or. string_pattern_grep( yfield,"." ) ) then
            locr = wrf_user_find_ij_lat_long( a, yofblsection, xofblsection )
            xofblsection = locr(1)   ; note this is 0 based
            yofblsection = locr(0)   ; note this is 0 based
           ;4testprint: print( "*** xfield,yfield="+xfield+","+yfield+" X,Yofblsection="+xofblsection+","+yofblsection )
         end if
         anglefield = extract_string_field( PARAMS(iparam), 4, "_" )
         if ( anglefield .ne. "" ) then
           if ( anglefield .ne. "windk" ) then
             mapangledeg = stringtofloat(anglefield)
           else   
             windk = stringtointeger( extract_string_field( PARAMS(iparam), 5, "_" ) )
             ;;; use wind at specified level for map angle
             if ( .not. isvar("ua") ) then 
               ua  = wrf_user_getvar(a,"ua",time)  ; in m/s
               ;;; convert to pilot units (english)
               if( UNITS .ne. "metric" ) then
                  ua = ua * 1.94386
               end if
             end if
             if ( .not. isvar("va") ) then 
               va  = wrf_user_getvar(a,"va",time)   ; in m/s
               ;;; convert to pilot units (english)
               if( UNITS .ne. "metric" ) then
                  va = va * 1.94386
               end if
             end if
             ;;; find map angle for wind vector
             ispot = floattointeger(xofblsection)  ; note this based on index 0
             jspot = floattointeger(yofblsection)  ; note this based on index 0
             mapangledeg = uv2mapangle( ua(windk,jspot,ispot),va(windk,jspot,ispot) )
             ;4testprint: print( "*** anglefield,windk="+anglefield+","+windk+" ua,va="+ua(windk,jspot,ispot)+","+va(windk,jspot,ispot)+" mapangledeg="+mapangledeg )
           end if
         end if
       end if
       mapangledeginteger = floattointeger( mapangledeg )
       ;;; sanity check - skip locations outside the grid - note 0 IS an error condition
       ;;; print info
       if( xofblsection .gt. 0.0 .and. xofblsection .lt. isize .and. yofblsection .gt. 0.0 .and. yofblsection .lt. jsize ) then
         print ( "       SLICE AT X,Y="+xofblsection+","+yofblsection+" - angle="+mapangledeginteger )
       else
         print ( "       **SKIPPING** SLICE AT X,Y="+xofblsection+","+yofblsection+" - outside grid limits="+isize+","+jsize )
         continue
       end if
     end if
     ;;; END OF EXTRACTION OF X,Y,ANGLE FROM PARAMETER NAME
     ;;; --------------------------------------------------------------------------------
 
     ;;; --------------------------------------------------------------------------------
     ;;; START OF BOX W MAX ANALYSIS
     ;;; NB: any later press??? will include boxwmax info and position in plot (since ldowautosection=1 )
     if( name_max .eq. 6 .and. name_chars(0:6) .eq. "boxwmax" ) then
        print ( "    DOING BOXwMAX ANALYSIS" )

        ;;; ALLOW AUTO SECTION THROUGH LOCATION OF MAX W  (but presently off-set by 0.5*dx)
        ;;; SET AUTO SECTION FLAG SO LATER PRESSURE PLOTS WILL UTILIZE BOXWMAX INFO
        ldowautosection = 1
          if ( .not. isvar("w") ) then 
            w = wrf_user_getvar(a,"wa",time) ; vertical velocity, averaged to half levels in m/s
          end if
          ;;; SO AUTO-SECTION BASED ON MAX W IN 3D BOX
          ;;; set box - presently based on frame around horiz. border
          wdims = dimsizes(w)
          kwdim = wdims(0)
          jwdim = wdims(1)
          iwdim = wdims(2)
          ;;;  *NB* 0-based indexing used for boximin,...
          if( boxframe .gt. 0 ) then
            boximin = boxframe
            boximax = iwdim-boxframe-1
            boxjmin = boxframe 
            boxjmax = jwdim-boxframe-1
          end if
          if( boxframe .eq. -3 ) then
            boximin = iwdim/3
            boximax = iwdim-(iwdim/3)
            boxjmin = jwdim/3
            boxjmax = jwdim-(jwdim/3) 
          end if
          ;old kbox2_wautosection = kwdim -2
          ;;; find location of max w in box
          wmax = new( 1, float)
          imaxw = new( 1, integer)
          jmaxw = new( 1, integer)
          kmaxw = new( 1, integer)
          NCL_JACK_FORTRAN :: find_boxmax3d( w, boximin,boximax, \
                                  boxjmin,boxjmax, \
                                  boxkmin,boxkmax, \
                                  isize,jsize,ksize, wmax,imaxw,jmaxw,kmaxw )
          ;4test: 
 print ( "    DIMs= "+wdims(2)+" "+wdims(1)+" "+wdims(0) )
          ;4test: 
 print ( "    SIZEs= "+isize+" "+jsize+" "+ksize )
          ;4test: 
 print ( "    BOX= "+boximin+"-"+boximax+" "+boxjmin+"-"+boxjmax+" "+boxkmin+"-"+boxkmax )
          ;4test: 
 print ( "    I,Jmaxw= "+imaxw+" "+jmaxw )
          wmaxcmps = 100. * wmax 
          ;;; convert to integer for printing
          wmaxcmps = floattointeger( wmaxcmps )
          ;old alat  = wrf_user_getvar(a,"XLAT",time)
          ;old alon  = wrf_user_getvar(a,"XLONG",time)
          latmaxw = sprintf ( "%.2f", alat(jmaxw,imaxw) )
          lonmaxw = sprintf ( "%.2f", alon(jmaxw,imaxw) )
          zmaxw = floattointeger( z(kmaxw,jmaxw,imaxw) )
          ;old delete ( alat )
          ;old delete ( alon )
          ;;; use this location for vertical cross-section
          xofblsection = imaxw +0.0   ; note this is 0 based
          yofblsection = jmaxw +0.0   ; note this is 0 based
 ;;;jack - print z for info
 ;;; might want to set top of box based on z - but presently not done
 ;;; find z of each k at domain center
if ( .not. isvar("pmb") ) then 
  pmb = wrf_user_getvar(a,"p",time) ; pressure in mb
end if
ispot = floattointeger(xofblsection)  ; note this based on index 0
jspot = floattointeger(yofblsection)  ; note this based on index 0
;old  ispot = (iwdim-1)/2
;old  jspot = (jwdim-1)/2
;4test  ispot = 0
;4test  jspot = 0
 print ( "    Zlevels @ij(0based)="+ispot+","+jspot )
 do kk=0,(kwdim-1)
   kkreverse = kwdim-kk-1
   print ( "    @k="+kkreverse+"  Z= "+z(kkreverse,jspot,ispot)+"  P= "+pmb(kkreverse,jspot,ispot) )
 end do          
;old delete (pmb)
          ;;; set angle as that of wind at that location (0-180deg) (left-to-right except 0=180deg=>bottom-to-top)
          if ( .not. isvar("ua") ) then 
            ua  = wrf_user_getvar(a,"ua",time)  ; in m/s
            ;;; convert to pilot units (english)
            if( UNITS .ne. "metric" ) then
               ua = ua * 1.94386
            end if
          end if
          if ( .not. isvar("va") ) then 
            va  = wrf_user_getvar(a,"va",time)   ; in m/s
            ;;; convert to pilot units (english)
            if( UNITS .ne. "metric" ) then
               va = va * 1.94386
            end if
          end if
          ;;; find map angle for wind vector
          mapangledeg = uv2mapangle( ua(kmaxw,jmaxw,imaxw),va(kmaxw,jmaxw,imaxw) )
          mapangledeginteger = floattointeger( mapangledeg )
          ;old delete ( ua )
          ;old delete ( va )
          ;4test  mapangledeg = 90.
          ;4test  print ( "   U,V,ANGLE= "+ua(kmaxw,jmaxw,imaxw)+" "+va(kmaxw,jmaxw,imaxw)+" "+mapangledeg )
          ;;; print info
          print ( "       W MAX= "+wmaxcmps+"cm/s @ijk"+imaxw+","+jmaxw+","+kmaxw+" ="+latmaxw+","+lonmaxw+","+zmaxw+"m - angle="+mapangledeginteger )
          ;old print ( "W MAX= "+array(0)+" @ijk="+imaxw+","+jmaxw+","+kmaxw )
          ;old print ( "  at height(m)="+zmaxw+" (BoxTop@k="+boxkmax+"="+z(kmaxw,jmaxw,boxkmax)+"m)" )
          ;4test:  print ( "W MAX= "+w(kmaxw,jmaxw,imaxw)+" @ijk="+imaxw+","+jmaxw+","+kmaxw )
 
     end if
     ;;; END OF BOX W MAX ANALYSIS
     ;;; --------------------------------------------------------------------------------

        ;;; CROSS-SECTION PARAMS
        aspect_ratio = .75

;                   ^
;       angle  0 is |
;                   |
;                    ^ 
;       angle 45 is /
;                  /
;
;       angle= 90 is ---->
;
;                    \ 
;       angle 135 is  \
;                      v
  ;original=bad! ;;         Two different cross-sections, angle=90 is |, angle=0 is ------
        
;;;         ************************************************************

    ;;; ALLOW PLOTTING TO INDIVIDUAL OUTPUT FILES
    if ( LOUT .ge. 2 ) then
      ;RASP
      if( ismissing(ENV_NCL_OUTDIR) .or. ENV_NCL_OUTDIR .eq. "" ) then
        wks = wrf_open_ncgm(plot_param)   ; output to ncgm
        ;old wks = wrf_open_ncgm("rasp."+iframe)   ; output to ncgm
      else
        if( ldatatype.ne.0 .and. qfileid.ne."" ) then
          ;alt if( ENV_NCL_OUTDIR.eq."/tmp" .and. qfileid.ne."" ) then
          ;;; append tail for write to /tmp directory
          wks = wrf_open_ncgm(OUTDIR+"/"+plot_param+"."+qfileid)   ; output to ncgm
        else
          wks = wrf_open_ncgm(OUTDIR+"/"+plot_param)   ; output to ncgm
          ;old wks = wrf_open_ncgm(OUTDIR+"/rasp.wrf."+iframe)   ; output to ncgm
        end if
      end if
      ;;; INCREASE WORKSPACE ABOVE DEFAULT IF REQUESTED
      if( WORKSTATIONSPACE .gt. 0 ) then
        setvalues NhlGetWorkspaceObjectId()
           "wsMaximumSize": WORKSTATIONSPACE
        end setvalues
      end if
    end if

;;;         ************************************************************

      ;jack - these variables needed for bl cross-section
      if( lblsectionvar .eq. 1 ) then
        if ( .not. isvar("thetac") ) then 
           thetac = 26.85 + wrf_user_getvar(a,"T",time) ; perturb. potential temp. in degC
        end if
      else  
        if ( .not. isvar("rh") ) then 
            rh = wrf_user_getvar(a,"rh",time) ; perturb. potential temp. in degC
        end if
      end if
        if ( .not. isvar("w") ) then 
          w = wrf_user_getvar(a,"wa",time) ; vertical velocity, averaged to half levels in m/s
          ;;; convert w into cm/s
        end if
        w4plot = 100*w

;;;         ************************************************************
                ;        Build planes of data for w and thetac/rh
                plane = new(2,float)
                ;jack - plane sets point plane is to pass through
                ;jack plane = (/ dimsthetac(2)/2, dimsthetac(1)/2 /)
                plane = (/ xofblsection, yofblsection /)
                
                if( lblsectionvar .eq. 1 ) then
                   ;;; convert to pilot units (english)
                   if( UNITS .ne. "metric" ) then
                      var_plane = wrf_user_intrp3d(thetac,z,terft,"v",plane,mapangledeg)
                   else
                     var_plane = wrf_user_intrp3d(thetac,z,ter,"v",plane,mapangledeg)   
                   end if
                else
                   ;;; convert to pilot units (english)
                   if( UNITS .ne. "metric" ) then
                      var_plane = wrf_user_intrp3d(rh,z,terft,"v",plane,mapangledeg)
                   else
                      var_plane = wrf_user_intrp3d(rh,z,ter,"v",plane,mapangledeg)
                   end if
                end if
                ;;; convert to pilot units (english)
                if( UNITS .ne. "metric" ) then
                   w_plane = wrf_user_intrp3d(w4plot,z,terft,"v",plane,mapangledeg)
                else
                   w_plane = wrf_user_intrp3d(w4plot,z,ter,"v",plane,mapangledeg)
                end if

                ;;; PRINT MIN,MAX
                print( "    "+times(it)+" "+iframe+"= BL CROSS-SECTION: W [cm/s] MIN,MAX= "+min(w_plane)+"  "+max(w_plane) )
                if( lblsectionvar .eq. 1 ) then
                  print( "                                           Theta [C] MIN,MAX= "+min(var_plane)+"  "+max(var_plane) )
                else
                  print( "                                           RH [%] MIN,MAX= "+min(var_plane)+"  "+max(var_plane) )
                end if

                ;        Plotting options for w
                opts_w = True
                if ( ldowautosection .eq. 0 .and. anglefield .ne. "windk" ) then
                  if( mapangledeg.ge.0.0 .and. mapangledeg.le.0.5 .or. mapangledeg.ge.179.5 .and. mapangledeg.le.180.5 ) then
                    if( lblsectionvar .eq. 1 ) then
                      opts_w@MainTitle = "Y-parallel Vertical Velocity & Pot.Temp. ~I~(C)~P~"
                    else
                      opts_w@MainTitle = "Y-parallel Vertical Velocity & Rel.Humid. ~I~(%)~P~"
                    end if
                  end if
                  if( mapangledeg.ge.89.5 .and. mapangledeg.le.90.5 ) then
                    if( lblsectionvar .eq. 1 ) then
                      opts_w@MainTitle = "X-parallel Section: Vertical Velocity & Pot.Temp ~I~(C)~P~"
                    else
                     opts_w@MainTitle = "X-parallel Section: Vertical Velocity & Rel.Humid. ~I~(%)~P~"
                    end if
                  end if
                  if( (mapangledeg.gt.0.5 .and. mapangledeg.lt.89.5 ) .or. ( mapangledeg.gt.90.5 .and. mapangledeg.lt.179.5 ) ) then
                     if( lblsectionvar .eq. 1 ) then
                       opts_w@MainTitle = "Angled Section: Vertical Velocity & Pot.Temp. ~I~(C)~P~"
                     else
                       opts_w@MainTitle = "Angled Section: Vertical Velocity & Rel.Humid. ~I~(%)~P~"
                     end if
                  end if
                  opts_w@LevelLabel = "slice X,Y= "+xofblsection+","+yofblsection+"@"+mapangledeginteger+"~F34~0~F21~"
                else
                  if( lblsectionvar .eq. 1 ) then
                    opts_w@MainTitle = "Wind-Parallel Section at Max W: Vertical Velocity & Pot.Temp. ~I~(C)~P~"
                  else
                    opts_w@MainTitle = "Wind-Parallel Section at Max W: Vertical Velocity & RH ~I~(%)~P~"
                  end if
                  if ( ldowautosection .eq. 1 ) then
                    opts_w@LevelLabel = "boxWmax="+wmaxcmps+"@"+latmaxw+","+lonmaxw+","+zmaxw+"m"
                  else
                    opts_w@LevelLabel = "i,j,k,angle="+xofblsection+","+yofblsection+","+windk+","+mapangledeginteger
                  end if
                  ;prelatlon opts_w@LevelLabel = "angle@X,Y= "+mapangledeginteger+"@"+imaxw+","+jmaxw+" Z="+zmaxw+"m"
                end if

                opts_w@UnitLabel = "Vertical Velocity [cm/s]"
                ;single_time_file:
                opts_w@TimeLabel = times(it)+"Z"
                  ;multiple_time_file: opts_w@TimeLabel = times(it) + " = " + time_save + " + " + hours + " h"
                ;;; IF NON-INTERACTIVERUN, USE ID AS TITLE
                if ( .not. ismissing(ENV_NCL_ID) .and. ENV_NCL_ID .ne. "" ) then
                  opts_w@TimeLabel = trim_string( ENV_NCL_ID )
                end if
                ;unused opts_w@ContourParameters = (/ -10., +10., 1. /)
                ;original opts_w@LevelLabel = "WRF MASS Forecast"
                ;original opts_w@cnFillColors = (/"white","white","white","white","chartreuse","green","green3","green4","forest green","PaleGreen4"/)
                opts_w@cnFillOn = True
                opts_w@cnMissingValPerimOn = True
                opts_w@cnMissingValFillColor = 0
                opts_w@cnMissingValFillPattern = 11
                opts_w@AspectRatio = aspect_ratio
                ;jack - now set top level based on data, not simply hard-wired!
                opts_w@tmYLMode          = "Automatic"     ; Set tick mark mode.
                ;jack - what a joke - simply assumes top of data/model always at 20km !
                ;original opts_w@tmYLMode          = "Explicit"     ; Set tick mark mode.
                ;original opts_w@tmYLValues        = (/ 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 /)
                ;original opts_w@tmYLLabels        = (/ 0,  2,  4,  6,  8, 10, 12, 14, 16, 18,  20 /)
                ; tiAxis is for alphabetic string
                ;old opts_w@tiXAxisString   = "Grid Point"  ; Label for the X axis
                ;;; convert to pilot units (english)
                if( UNITS .ne. "metric" ) then
                   opts_w@tiYAxisString   = "Height [Kft MSL]"      ; Label for the Y axis
                  ;jack - for x axis use length instead of grid point
                  opts_w@tiXAxisString   = "Distance [nm]"  ; Label for the X axis
                else
                   opts_w@tiYAxisString   = "Height [km MSL]"      ; Label for the Y axis
                  ;jack - for x axis use length instead of grid point
                  opts_w@tiXAxisString   = "Distance [km]"  ; Label for the X axis
                end if
                opts_w@tiXAxisFont     = "helvetica"        ; Font for X axis label
                opts_w@tiYAxisFont     = "helvetica"        ; Font for Y axis label
                opts_w@tiXAxisFontHeightF = 0.020
                opts_w@tiYAxisFontHeightF = 0.018
                ; tmLabel is for numbers
                opts_w@tmXBLabelFont     = "helvetica"        ; Font for X number label
                opts_w@tmXBLabelFontHeightF     = 0.020
                opts_w@tmYLLabelFont     = "helvetica"        ; Font for Y number label
                opts_w@tmYLLabelFontHeightF     = 0.020
                opts_w@cnInfoLabelOn = False
                ; move y label to right, away from left border             
                opts_w@tmYLLabelDeltaF        = -0.5
                ; move x label to top, away from bottom border             
                opts_w@tmXBLabelDeltaF        = -0.5

                ;;; FOR LABEL BAR (COLORBAR)
                opts_w@lbAutoManage = False
                opts_w@lbLabelFont     = "helvetica"   ; for numbers 
                opts_w@lbLabelFontHeightF     = 0.015
                opts_w@lbTitleFontHeightF     = 0.015
                opts_w@lbLabelOffsetF     = 0.05  ; move numbers close to colorbar
                opts_w@lbTitleFont     = "helvetica"   ; for string
                ;preAug2006(smaller_plotheight) opts_w@lbTitleFontHeightF     = 0.015
                ;preAug2006(smaller_plotheight) opts_w@lbTitleOffsetF     = -0.5  ; move colorbar and its title closer together
                ;preAug2006(smaller_plotheight) opts_w@lbTopMarginF     = -0.2  ; move colorbar and its title upward, closer to plot - but also expands height of colorbar !
                ;preAug2006(smaller_plotheight) opts_w@lbBottomMarginF  = 0.4

                ;;; LABELBAR OPTIONS TO ALLOW LARGER VERTICAL PLOT - but _with_ title
                ;;; specify label bar height,width to conform to my esthetics
                opts_w@pmLabelBarHeightF  = 0.08 ; 
                opts_w@pmLabelBarWidthF  = 0.80 ; 
                ;old opts_w@pmLabelBarWidthF  = 0.78 ; 
                opts_w@lbBottomMarginF     = 0.0 ; no apparnet effect
                opts_w@lbTopMarginF     = 0.0 ; no apparnet effect
                opts_w@pmLabelBarOrthogonalPosF  = 0.0 ; moves slightly upward
                ;unused  opts_w@lbJustification = "TopCenter" set in subroutine so not set here
                ;unused opts_w@pmLabelBarZone  = 1 ; when label bar perim extends beyond plot boundary this moves lb closer to plot 
                ;4test-display_lb_perim: opts_bparam@lbPerimOn = True ; opts_bparam@lbPerimColor = 1

                ;        Plotting options for thetac
                opts_thetac = True
                opts_thetac@NoTitles = True
                opts_thetac@ContourParameters = (/ 0.,0., 1. /)
                ;512x512:opts_thetac@cnLineLabelFontHeightF = .010
                ;800x800
                opts_thetac@cnLineLabelFontHeightF = .0022
                opts_thetac@cnInfoLabelOn = False
                ;jack - use of contour info label causes colorbar numbers to disappear
                opts_thetac@cnInfoLabelOn = False

                ;;;  Plot options for rh contour lines (no titles/labels)
                opts_rh = True
                opts_rh@NoTitles = True
                opts_rh@ContourParameters = (/ 10., 90., 10. /)
                opts_rh@cnLineLabelBackgroundColor = -1
                opts_rh@cnLineLabelFontHeightF = .005
                opts_rh@cnInfoLabelOn = False
                ;jack - use of contour info label causes colorbar numbers to disappear
                opts_rh@cnInfoLabelOn = False

                ;;;;;; this controls top height
                ;;; set default bl section top if not set above
                if( blsectionztop .le. 0 ) then
                   if( UNITS .ne. "metric" ) then
                      blsectionztop = 18.   ; in Kft
                   else
                      blsectionztop = 6.   ; in Km
                   end if
                end if
                ;jack - for vertical windowing, set min/max IN KM
                opts_w@trYMinF        = 0.
                opts_w@trYMaxF        = blsectionztop
                opts_rh@trYMinF        = 0.
                opts_rh@trYMaxF        = blsectionztop
                opts_thetac@trYMinF        = 0.
                opts_thetac@trYMaxF        = blsectionztop

                ;jack - for vertical windowing, use actual coordinate values of the data IN KM
                ;;; convert to pilot units (english)
                if( UNITS .ne. "metric" ) then
                   minZ = 0.0032808 * min(z) ; in kFT !
                   maxZ = 0.0032808 * max(z) ; in kFT !
                else
                   minZ = 0.001 * min(z) ; in KM !
                   maxZ = 0.001* max(z) ; in KM !
                   ;4test: print ( "Zmin,max[km]= "+minZ+" "+maxZ )
                end if
                w_plane@_MinY = minZ
                w_plane@_MaxY = maxZ
                var_plane@_MinY = minZ
                var_plane@_MaxY = maxZ

                ;jack - for x axis use length instead of grid point
                wplane_dims = dimsizes(w_plane)
                slicelength = (wplane_dims(1)-1) * 0.001 * dx
                ;;; for non-metric, convert slice length from km to nm (per x axis label)
                if( UNITS .ne. "metric" ) then
                  slicelength = 0.539956 * slicelength 
                end if
                w_plane@_MinX = 0.
                w_plane@_MaxX = slicelength
                var_plane@_MinX = 0.
                var_plane@_MaxX = slicelength

               ;;; FOR SITE SUBSTITUTIONS  (jack: if alter filename also change BLIP/PLOT/filename)
               ;bad_routine= load_scriptfile( "rasp.site_load.bl-xsection.ncl" )
               load "rasp.site_load.bl-xsection.ncl" 

                ;        Get the contour info for the w and thetac/rh
                contour_w = wrf_new_fill_contour( wks,w_plane,opts_w,  mainvpx,mainvpy,mainvpwidth,mainvpheight )
                ;pre-viewport_params                contour_w = wrf_new_fill_contour(wks,w_plane,opts_w)
if( lblsectionvar .eq. 1 ) then
                contour_var = wrf_new_line_contour( wks, var_plane,opts_thetac,  mainvpx,mainvpy,mainvpwidth,mainvpheight )
               ;pre-viewport_params  contour_var = wrf_new_line_contour(wks, var_plane,opts_thetac)
else
               contour_var = wrf_new_line_contour( wks, var_plane,opts_rh,  mainvpx,mainvpy,mainvpwidth,mainvpheight )
               ;pre-viewport_params                contour_var = wrf_new_line_contour(wks, var_plane,opts_rh)
end if
                ;        Overlay the fields on the background
;jack - but no apparent difference
                wrf_mapoverlay(contour_w,contour_var)
                draw(contour_w)

                ;;; FINALLY, DRAW FRAME
                frame(wks)

                ;        Remove the dummy stuff
                delete(contour_var)
                delete(contour_w)
                delete(var_plane)
                delete(w_plane)
                ; must delete opts_w for multi-file plots with both press-level and bl-section plots
                delete( opts_w )
                delete( opts_thetac )
                delete( opts_rh )

      ;;; print current wall clock & elapsed time
      PrintWallClockElapseTime(wcStrt,"BL cross-section Plot end -")

      continue 
   end if        ;        end of bl cross-section plot section

;;; =======================================================================
