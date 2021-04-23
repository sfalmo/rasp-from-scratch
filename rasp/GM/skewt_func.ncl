;;; FOLLOWING CHANGES BY Jack Glendening (drjack@drjack.net)
;;;JACK - use helvetica for every font
;;;JACK - changed main title font height
;;;JACK-line_only - removed std.press,pibal markers on vertical windbarb baseline
;;;JACK - allow control over P used for top of plot = Ptop
;;;JACK - inserted kludge to produce thin windbarbs
;;;JACK - wmbarb function that plots wind barb must be in fortran library
;;;JACK - add line plot of wind speed, with range automatically fixed as either low/high (green/red line)
;;;JACK - add line plot of cldfra = cloud fraction
;;;JACK - add line plot of qcloud = cloud moisture
;;;JACK - add plot of surface T and Td as dots
;;;JACK - use same function code as rasp.ncl
;;;JACK - add line plot of tke instead of cldfra when dataOpts@PlotTKE=True
;;;JACK - DANGER - NOTE REVERSAL OF SIGN FOR U,V HERE FROM SHEA VERSION

;;;PAULS - Add lines at pressure levels 950 & 900 mB

; -------------------------------------------------
; Dennis Shea
; email: shea@ucar.edu
; ------------------------------------------------
function skewty(pres[*]:numeric)            ; y-coord given pressure (mb)
  begin                             
   return (132.182-44.061*log10(pres))
  end

function skewtx(temp[*]:numeric,y[*]:numeric) ; x-coord given temperature (c)
  begin                                     ; y=skewty(p)
   return (0.54*temp+0.90692*y)
  end

;========================================================================================

function skewT_BackGround (wks:graphic,  Opts:logical)
  begin
; statement of purpose.
; ---------------------
; this program generates a skew-t, log p thermodynamic diagram.  this
; program was derived to reproduce the USAF skew-t, log p diagram.
;        (form dod-wpc 9-16-1  current as of march 1978)
; source.
; --------                    
; Tom Schlatter and Joe Wakefield [NOAA/PROFS] supplied fortran codes.
;
; history.
; --------                    
; don baker      01 jul 85    original version.  [NOAA/PROFS]
; don baker      01 dec 85    updated for product version.
; dennis shea       oct 98    created the NCL version
; dennis shea     9 feb 99    fix: MoistAdiabat labels at top of curves

  localOpts                   = True
  localOpts@DrawIsotherm      = True
  localOpts@DrawIsobar        = True
  localOpts@DrawMixRatio      = True
  localOpts@DrawDryAdiabat    = True
  localOpts@DrawMoistAdiabat  = True ; aka: saturation or pseudo adibat
  localOpts@DrawWind          = True
  localOpts@DrawStandardAtm   = False
  ;original  localOpts@DrawStandardAtm   = True
  localOpts@DrawColLine       = True 
  localOpts@DrawColAreaFill   = False 
  ;original  localOpts@DrawHeightScale   = False
  localOpts@DrawHeightScale   = True
;;;JACK
  localOpts@DrawHeightScaleFt = True  ;default is feet [otherwise km] 
  ;original  localOpts@DrawHeightScaleFt = False  ;default is feet [otherwise km] 
  localOpts@DrawStandardAtmThk= 2.0
  localOpts@Font              = "helvetica"
                              ; NCL resource names
  localOpts@tiMainString      = "   "
  localOpts@vpXF              = 0.07
  localOpts@vpYF              = 0.925 
  localOpts@vpWidthF          = 0.85
  localOpts@vpHeightF         = 0.85

                                      ; Override localOpts
                                      ; with input Opts
  if (Opts .and. .not.any(ismissing(getvaratts(Opts)))) then
      localAtts = getvaratts(localOpts)
      OptsAtts  = getvaratts(Opts)
      nOpts     = dimsizes  (OptsAtts)
      do i=0,nOpts-1
         if (any(OptsAtts(i).eq.localAtts)) then
             localOpts@$OptsAtts(i)$ = Opts@$OptsAtts(i)$
         end if 
      end do
  end if

; --- declare isotherm [C] values and pressures [hPa] where isotherms 
; --- intersect the edge of the skew-t diagram.

  temp = (/-100.,-90.,-80.,-70.,-60.,-50.,-40.,-30.             \
          , -20.,-10.,  0., 10., 20., 30., 40., 50.             /)
  lendt= (/ 132., 181., 247., 337., 459., 625., 855.            \
          ,1050.,1050.,1050.,1050.,1050.,1050.,1050.,1050.,1050./)
  rendt= (/ 100., 100., 100., 100., 100., 100., 100.            \
          , 135., 185., 251., 342., 430., 500., 580., 730., 993./)
  ntemp= dimsizes (temp)                ; isotherms
  if (dimsizes(lendt).ne.dimsizes(rendt) .or. \
      dimsizes(lendt).ne.ntemp) then
      print ("Error: dimsizes temp, lendt, rendt do not match")
      exit
  end if

; --- declare pressure values [hPa] and x coordinates of the endpoints of each
; --- isobar.  these x,y values are computed from the equations in the
; --- transform functions listed at the beginning of this program.  
; --- refer to a skew-t diagram for reference when necessary.

; PaulS - Add 950 & 900
  pres = (/1050., 1000.,  950.,  900.,  850.,  700.,  500.,  400.,  300.,  250.,  200.,  150.,  100./)
  xpl  = (/-19.0, -19.0, -19.0, -19.0, -19.0, -19.0, -19.0, -19.0, -19.0, -19.0, -19.0, -19.0, -19.0/)
  xpr  = (/ 27.1,  27.1,  27.1,  27.1,  27.1,  27.1, 22.83,  18.6,  18.6,  18.6,  18.6,  18.6,  18.6/)
  npres= dimsizes (pres)                ; pressures
  if (dimsizes(xpl).ne.dimsizes(xpr) .or. dimsizes(xpl).ne.npres) then
      print ("Error: dimsizes pres, xpl, xpr do not match")
      exit
  end if

; --- declare adiabat values [C] and pressures where adiabats intersect the
; --- edge of the skew-t diagram.  refer to a skew-t diagram when necessary.

  theta=  (/-30.,-20.,-10.,0.,10.,20.,30.,40.,50.,60.,70.,80.,90.  \
           ,100.,110.,120.,130.,140.,150.,160.,170.                /)
  lendth= (/880.,670.,512.,388.,292.,220.,163.,119.,100.,100.,100. \
           ,100.,100.,100.,100.,100.,100.,100.,100.,100.,100.      /)
  rendth= (/1050.,1050.,1050.,1050.,1050.,1050.,1050.,1050. \
           ,1003.,852.,728.,618.,395.,334.,286., 245., 210. \
           , 180.,155.,133.,115. /)
  ntheta= dimsizes (theta)                ; dry adiabats 
  if (dimsizes(lendth).ne.dimsizes(rendth) .or. \
      dimsizes(lendth).ne.ntheta) then
      print ("Error: dimsizes theta, lendth, rendth do not match")
      exit
  end if

; --- declare moist adiabat values and pressures of the tops of the
; --- moist adiabats. all moist adiabats to be plotted begin at 1050 mb.

  pseudo = (/ 32., 28., 24., 20., 16., 12.,  8. /)
  lendps = (/250.,250.,250.,250.,250.,250.,250. /)
  npseudo= dimsizes (pseudo)              ; moist adiabats

; --- declare mixing ratio lines.  all mixing ratio lines will begin 
; --- at 1050 mb and end at 400 mb.

  mixrat= (/ 20.,12.,8.,5.,3.,2.,1. /)
  nmix  = dimsizes (mixrat)              ; mixing ratios

; --- declare local stuff: arrays/variables for storing x,y positions 
; --- during iterations to draw curved line, etc

  sx    = new (200, float)
  sy    = new (200, float)
  xx    = new (  2, float)
  yy    = new (  2, float)
  label = new (  1, string)
  m2f   = 3.2808             ; meter-to-feet
  f2m   = 1./3.2808          ; feet-to-meter

; --- define absolute x,y max/min bounds corresponding to the outer
; --- edges of the diagram.  these are computed by inserting the appropriate
; --- pressures and temperatures at the corners of the diagram.

;;;JACK - allow control over P used for top of plot = Ptop
;;; must set Ptop in both skewT_BackGround and skewT_PlotData
Ptop = 250. 

xmin =-19.0    ; xmin =? skewtx (-109.1,skewty(100.))  [t=deg C]
xmax = 27.1    ; xmax = skewtx (51.75, skewty(1050.)) [t=deg C]
ymax =-0.935   ; ymax = skewty (1050.)  
;old ymin =44.061   ; ymin = skewty ( 100.)
;4test:  ymin =24.0   ; just above~300mb

;;;JACK - allow control over P used for top of plot = Ptop
ymin = skewty ( Ptop )  

;;;JACK - use explicit calc so can test changes
;original?  xmin = skewtx (-109.1,skewty(100.)) ; args=t(degC),y(fromPmb)
;original?  xmax = skewtx (51.75, skewty(1050.)) ; args=t(degC),y(fromPmb)
;original?  ymin = skewty ( 300.) ; arg=pressure(mb)
;original?  ymax = skewty (1050.) ; arg=pressure(mb) 
;test print ( xmin+" "+xmax+" "+ymin+" "+ymax )
; "original?" calcs give  xmin,xmax,ymin,ymax= -18.9551 27.0974 23.0376 -0.934616 
; note that ymin differs from that used above !
; but using original? values compresses plot in x direction, not in y ! ?


; --- specify arrays to hold corners of the diagram in x,y space. 

  xc    = (/ xmin, xmin, xmax, xmax, 18.60, 18.6, xmin /)
  yc    = (/ ymin, ymax, ymax,  9.0, 17.53, ymin, ymin /)

; ---- depending on how options are set create Standard Atm Info

  if (localOpts@DrawStandardAtm .or. \ 
      localOpts@DrawHeightScale .or. localOpts@DrawWind) then
                                 ; U.S. Standard ATmosphere
      zsa = fspan (0. , 16., 17) ; (km) source Hess/Riegel
      psa = (/ 1013.25, 898.71, 794.90, 700.99, 616.29, 540.07   \
             ,  471.65, 410.46, 355.82, 307.24, 264.19           \
             ,  226.31, 193.93, 165.33, 141.35, 120.86,103.30    /)
      tsa = (/   15.0 ,   8.5 ,   2.0 ,  -4.5 , -11.0 , -17.5    \
             ,  -24.0 , -30.5 , -37.0 , -43.5 , -50.0            \
             ,  -56.5 , -56.5 , -56.5 , -56.5 , -56.5 , -56.5    /)
      nlvl= dimsizes (psa)
  end if

; PLOT

  if (localOpts@DrawColLine) then
      ;original colGreen            = "Green"
      colGreen              = "(/ .55, 0.75, .55 /)"  ;
      colBrown            = "Brown"
;;;JACK - Tan does not exist as defined color in some colormaps
       colTan              = "(/ 1.0, .7, .5 /)"  ;
;      colTan              = "(/ .86, .56, .44 /)"  ; "tan" in cn14
;      colTan              = "(/ .82, .41, .12 /)"  ; "tan" in ngwww.ucar.edu/ngdoc/ng/ref/rgb.txt (divide by 255)
;       colTan              = "(/ 1.0, .65, .31 /)"  ; yellowish "tan1" in ngwww.ucar.edu/ngdoc/ng/ref/rgb.txt (divide by 255)
;       colTan              = "(/ .93, .60, .29 /)"  ; "tan2" in ngwww.ucar.edu/ngdoc/ng/ref/rgb.txt (divide by 255)
;       colTan              = "(/ .54, .35, .17 /)"  ; maroonish "tan4" in ngwww.ucar.edu/ngdoc/ng/ref/rgb.txt (divide by 255)
;original      colTan              = "Tan"
  else
      colGreen            = "Foreground" 
      colBrown            = "Foreground"
      colTan              = "Foreground"
  end if

; --- draw outline of the skew-t, log p diagram.  proceed in the upper left
; --- corner of the diagram and draw counter-clockwise.  the array locations
; --- below that are hardcoded refer to points on the background where the
; --- skew-t diagram deviates from a rectangle, along the right edge.  remember,
; --- the set call defines a rectangle, so as long as the boundary is along
; --- the edge of the set call, the points plotted are combinations of the min
; --- and maximum x,y values in the set call.
 
  ;;; convert to pilot units
  if( Opts@units .eq. "american" ) then
     tf = ispan (-20, 100, 20)      ; deg F [nice round numbers]
     tc = 0.55555*(tf-32.)          ; deg C corresponding to tf
  else
     tc = ispan (-30, 40, 10)       ; deg C [nice round integers]
     tf = tc                        ; for labels, not really farenheit
  end if
 
  xyOpts            = True      
  xyOpts@gsnDraw    = False  ; Don't draw the plot or advance the
  xyOpts@gsnFrame   = False  ; frame in the call to gsn_xy.
                             ; specify location/size of skewT diagram
  xyOpts@vpXF       = localOpts@vpXF
  xyOpts@vpYF       = localOpts@vpYF
  xyOpts@vpWidthF   = localOpts@vpWidthF
  xyOpts@vpHeightF  = localOpts@vpHeightF

  xyOpts@tmYLMode   = "Explicit" ; Define y tick mark labels.
  xyOpts@tmYLValues = skewty ( pres(1:)) ; skip 1050
  ; PaulS - Add 950 & 900
  xyOpts@tmYLLabels = (/"1000","950","900","850","700","500","400","300" \
                       ,"250" , "200","150","100"/)

  xyOpts@tmXBMode   = "Explicit" ; Define x tick mark labels.
  xyOpts@tmXBValues = skewtx (tc, skewty(1050.)) ; transformed vals
  xyOpts@tmXBLabels = tf         ; plot the nice deg F

  xyOpts@trXMinF      = xmin
  xyOpts@trXMaxF      = xmax 
  xyOpts@trYMinF      = ymax       ; Note: ymin > ymax
  xyOpts@trYMaxF      = ymin
  xyOpts@xyComputeXMin= False
  xyOpts@xyComputeXMax= False
  xyOpts@xyComputeYMin= False
  xyOpts@xyComputeYMax= False
  xyOpts@tmXTOn       = False
  xyOpts@tmYROn       = False
  xyOpts@tmXTBorderOn = False
  xyOpts@tmXBBorderOn = False
  xyOpts@tmYRBorderOn = False
  xyOpts@tmYLBorderOn = False
                                   ; "tune" the plot
  xyOpts@tmXBMajorLengthF        = 0.01
  xyOpts@tmXBMajorThicknessF     = 1.0         ; default is 2.0
  xyOpts@tmXBMajorOutwardLengthF = 0.01
  xyOpts@tmXTMajorLengthF     = 0. 
  xyOpts@tmYLMajorLengthF     = 0.
  xyOpts@tmXBLabelFontHeightF = 0.014
  xyOpts@tmYLLabelFontHeightF = xyOpts@tmXBLabelFontHeightF
  ;;; convert to pilot units (english)
  if( Opts@units .eq. "american" ) then
    xyOpts@tiXAxisString        = "Temperature (F)"
  else
    xyOpts@tiXAxisString        = "Temperature (C)"
  end if
  xyOpts@tiXAxisFont          = localOpts@Font
  xyOpts@tiXAxisFontColor     = "Foreground"   ; colTan
  xyOpts@tiXAxisFontHeightF   = 0.0125
  xyOpts@tiYAxisFont          = localOpts@Font
  xyOpts@tiYAxisString        = "P (hPa)"
  xyOpts@tiYAxisOffsetXF      = 0.0200
  xyOpts@tiYAxisOffsetYF      = -0.0200
  xyOpts@tiYAxisFontColor     = "Foreground"   ; colTan
  xyOpts@tiYAxisFontHeightF   = xyOpts@tiXAxisFontHeightF
  xyOpts@tiMainString         = localOpts@tiMainString
;;;JACK - use same function code as rasp.ncl
  xyOpts@tiMainFuncCode       = "~"
  xyOpts@tiMainFont           = localOpts@Font
  xyOpts@tiMainFontColor      = "Foreground"   
  ;original  xyOpts@tiMainFontHeightF    = 0.02
;;;JACK
  xyOpts@tiMainFontHeightF    = 0.017
  xyOpts@tiMainOffsetXF       = 0.0

;;;JACK - change axis number font from default
  xyOpts@tmXBLabelFont     = "helvetica"        ; Font for X number label
  xyOpts@tmYLLabelFont     = "helvetica"        ; Font for Y number label

  if (localOpts@DrawHeightScale) then   ; special for rhs

      ;;;JACK - so height axis and wind axis bisected by skewt boundary
      xyOpts@trXMaxF      = skewtx (56.10 , skewty(1013.)) ; extra wide
      ;original xyOpts@trXMaxF      = skewtx (55. , skewty(1013.)) ; extra wide
      xyOpts@tmYUseLeft   = False ; Keep right axis independent of left.
      xyOpts@tmYRBorderOn = True
      xyOpts@tmYROn       = True  ; Turn on right axis tick marks.
      xyOpts@tmYRLabelsOn = True  ; Turn on right axis labels.
      xyOpts@tmYRLabelFontHeightF    = xyOpts@tmYLLabelFontHeightF
      xyOpts@tmYRMajorThicknessF     = xyOpts@tmXBMajorThicknessF
      xyOpts@tmYRMajorLengthF        = xyOpts@tmXBMajorLengthF
      xyOpts@tmYRMajorOutwardLengthF = xyOpts@tmXBMajorOutwardLengthF
      xyOpts@tmYRMinorOn             = False       ; No minor tick marks.
      xyOpts@tmYRMode                = "Explicit"  ; Define tick mark labels.

;;;JACK - change axis numbers from default
      xyOpts@tmYRLabelFont     = "helvetica"        ; Font for Y number label

      zkm = fspan (0. , 16., 17) 
      pkm = ftcurv(zsa,psa,zkm)
      zft = (/ 0., 2., 4., 6., 8.,10.,12.,14.,16.,18.,20.,\
            22.,24.,26.,28.,30.,32.,34.,36.,38.,40.,42.,44.,46.,48.,50. /)
      ;;;JACK
      ;original        25.,30.,35.,40.,45.,50.     /)
      pft = ftcurv(zsa,psa,zft*f2m)  ; p corresponding to zkm
      if (localOpts@DrawHeightScaleFt) then
          znice =  zft        
          pnice = skewty(pft)
          zLabel= "Height (1000 Feet)"
      else
          znice = zkm
          pnice = skewty(pkm)  
          zLabel= "Height (km)"
      end if
      xyOpts@tmYRValues   = pnice ; At each "nice" pressure value, 
      xyOpts@tmYRLabels   = znice ; put a "height" value label.
  end if    ; DrawHeightScale

  xy = gsn_xy (wks,xc,yc,xyOpts)   ; draw outline; x and y axis

                      ; right *label* MUST be added AFTER xy created
  if (localOpts@DrawHeightScale) then
      txOpts                   = True
      txOpts@txAngleF          = 270.
      txOpts@txFontColor       = "Foreground"   ; colTan
      txOpts@txFontHeightF     = xyOpts@tmYLLabelFontHeightF
;;;JACK - set helvetica font for "Height" label
      txOpts@txFont            = "helvetica" 
      xlab                     = skewtx (53., skewty(1013.)) 
;;;JACK - allow control over P used for top of plot = Ptop
      ylab                     = 0.5*(ymin+ymax)
      ;old      ylab                     = skewty (350.)
      gsn_text (wks,xy,zLabel,xlab,ylab,txOpts) ; label rhs
      delete (txOpts)
  end if    ; DrawHeightScale

; --- Color Fill Area of plot
   
  if (localOpts@DrawColAreaFill) then
      color1 = "PaleGreen"       ; "LightGreen"
      color2 = "MintCream"       ; "Azure"
      gsOpts = True
      do i=0,ntemp-2
         if (i%2 .eq. 0) then    ; alternate colors
             gsOpts@gsFillColor  = color1
         else
             gsOpts@gsFillColor  = color2
         end if

         nx    = 3     ; this handles most cases
         sy(0) = skewty( lendt(i) )
         sx(0) = skewtx( temp(i)  , sy(0) )
         sy(1) = skewty( lendt(i+1) )
         sx(1) = skewtx( temp(i+1), sy(1) )
         sy(2) = skewty( rendt(i+1) )
         sx(2) = skewtx( temp(i+1), sy(2) )
         sy(3) = skewty( rendt(i) )
         sx(3) = skewtx( temp(i)  , sy(3) )
                                          ; special cases
         if (temp(i).eq.-40.) then
             nx = 5
             sy(0:nx) = (/   3.00, ymax, -0.935, 38.32, 44.06, 44.06 /)
             sx(0:nx) = (/ -18.88, xmin,-17.05 , 18.55, 18.55, 18.36 /)
         end if
         if (temp(i).eq.0.) then
             nx = 4
             sy(0:nx) = (/ -0.935,-0.935, 16.15, 17.53, 20.53 /)
             sx(0:nx) = (/ -0.850, 4.55 , 20.05, 18.55, 18.55 /)
         end if
         if (temp(i).eq.30.) then
             nx = 4
             sy(0:nx) = (/-0.935, -0.935,  6.02,  9.0 , 10.42 /) 
             sx(0:nx) = (/15.35 , 20.75 , 27.06, 27.06, 25.65 /)
         end if

         gsn_polygon(wks, xy, sx(0:nx),sy(0:nx),gsOpts) 
      end do
                                          ; special cases
      gsOpts@gsFillColor  = color2
      sy(0:2) = (/ 44.06, 44.06, 38.75 /) ; upper left triangle
      sx(0:2) = (/-14.04,-18.96,-18.86 /)
      gsn_polygon(wks, xy, sx(0:2),sy(0:2),gsOpts) 

      gsOpts@gsFillColor  = color2
      sy(0:2) = (/ ymax, 0.13, ymax   /) ; lower right triangle
      sx(0:2) = (/ xmax, xmax, 27.0   /) ; skewtx(51.6,ymax)
      gsn_polygon(wks, xy, sx(0:2),sy(0:2),gsOpts) 
      delete (gsOpts)
  end if

; --- draw diagonal isotherms. 
;     [brown with labels interspersed at 45 degree angle]
;     http://ngwww.ucar.edu/ngdoc/ng/ref/hlu/obj/GraphicStyle.obj.html
   
  if (localOpts@DrawIsotherm) then
      gsOpts                   = True
      gsOpts@gsLineDashPattern = 0            ; solid
      gsOpts@gsLineColor       = colTan     
      gsOpts@gsLineThicknessF  = 4.0
     ;gsOpts@gsLineLabelFontColor    = colTan
     ;gsOpts@gsLineLabelFontHeightF  = 0.0125 

      txOpts                   = True
      txOpts@txAngleF          = 45.
      txOpts@txFontColor       = gsOpts@gsLineColor
      txOpts@txFontHeightF     = 0.0140
      txOpts@txFontThicknessF  = 1.0

      do i=0,dimsizes(temp)-3

         yy(1) = skewty(rendt(i))
         xx(1) = skewtx(temp(i),yy(1))
         yy(0) = skewty(lendt(i))
         xx(0) = skewtx(temp(i),yy(0))
        ;gsOpts@gsLineLabelString  = floattointeger(temp(i))
         gsn_polyline (wks,xy,xx,yy,gsOpts) 

         xlab  = xx(1)+0.625     
         ylab  = yy(1)+0.55     
         label = floattointeger(temp(i))
         gsn_text(wks,xy,label,xlab,ylab,txOpts)

      end do 
      delete (gsOpts)
      delete (txOpts)
  end if  ; DrawIsotherm

; --- draw horizontal isobars.

  if (localOpts@DrawIsobar) then
      gsOpts                   = True 
      gsOpts@gsLineDashPattern = 0            ; solid
      gsOpts@gsLineColor       = colTan     
      gsOpts@gsLineThicknessF  = 4.0
     ;gsOpts@gsLineLabelFontColor    = colTan
     ;gsOpts@gsLineLabelFontHeightF  = 0.0125 

      do i=0,npres-1
         xx(0) = xpl(i)
         xx(1) = xpr(i)
         ypl   = skewty(pres(i))
         yy(0) = ypl
         yy(1) = ypl
         gsn_polyline (wks,xy,xx,yy,gsOpts) 
      end do       ; end "i=1,npres"
      delete (gsOpts)
  end if       ; DrawIsobar

; --- draw saturation mixing ratio lines.  these lines run between 1050 and 400
; --- mb. the 20 line intersects the sounding below 400 mb, thus a special case 
; --- is made for it.  the lines are dashed green. the temperature where each line
; --- crosses 400 mb is computed in order to get x,y locations of the top of
; --- the lines.

  if (localOpts@DrawMixRatio) then
      gsOpts                   = True ; polyline [graphic style] opts
      gsOpts@gsLineThicknessF  = 4.0
      gsOpts@gsLineDashPattern = 2             ; sat mix ratio only
      gsOpts@gsLineColor       = colGreen ;      "

      txOpts                   = True
      txOpts@txAngleF          = 65.           ;      "
      txOpts@txFontColor       = colGreen ;      "
      txOpts@txFontHeightF     = 0.0100        ;      "

      yy(1) = skewty(400.)  ; y at top [right end of slanted line]
      yy(0) = skewty(1000.) ; y at bottom of line [was 1050.]

      do i=0,nmix-1
         if (mixrat(i).eq.20.) then   
            yy(1) = skewty(440.)
           ;tmix  = THERMO::tmr(mixrat(i),440.)
            tmix  = tmr_skewt(mixrat(i),440.)
         else
            yy(1) = skewty(400.)
           ;tmix  = THERMO::tmr(mixrat(i),400.)
            tmix  = tmr_skewt(mixrat(i),400.)
         end if
         xx(1) = skewtx(tmix,yy(1))
        ;tmix  = THERMO::tmr(mixrat(i),1000.) ; was 1050
         tmix  = tmr_skewt(mixrat(i),1000.) ; was 1050
         xx(0) = skewtx(tmix,yy(0))
         gsn_polyline (wks,xy,xx,yy,gsOpts)   ; dashed green   

         xlab  = xx(0)-0.25
         ylab  = yy(0)-0.45
         label = floattointeger(mixrat(i))
         gsn_text(wks,xy,label,xlab,ylab,txOpts)
      end do    ; end "i=0,nmix-1"
      delete (gsOpts)
      delete (txOpts)
  end if    ; DrawMixRatio

; --- draw dry adiabats.  iterate in 10 mb increments to compute the x,y
; --- points on the curve.

  if (localOpts@DrawDryAdiabat) then
      gsOpts                   = True 
      gsOpts@gsLineDashPattern = 0            
      gsOpts@gsLineColor       = colTan     
      gsOpts@gsLineThicknessF  = 4.0

      txOpts                   = True
      txOpts@txAngleF          = 300.
      txOpts@txFontColor       = colTan
      txOpts@txFontHeightF     = 0.01
      txOpts@txFontThicknessF  = 1.0

      pinc = 10.

      do i=0,ntheta-1
         p = lendth(i)-pinc
         do j=0,dimsizes(sy)-1
            p = p+pinc
            if (p.gt.rendth(i)) then
               sy(j) = skewty(rendth(i))
              ;t     = THERMO::tda(theta(i),p)   ; get temp on dry adiabat at p
               t     = tda_skewt(theta(i),p)     ; get temp on dry adiabat at p
               sx(j) = skewtx(t,sy(j))
               break 
            end if
 
            sy(j) = skewty(p)
           ;t     = THERMO::tda(theta(i),p)
            t     = tda_skewt(theta(i),p)
            sx(j) = skewtx(t,sy(j))
         end do     ; end "j=0,dimsizes(sy)-1"
        ;gsn_polyline (wks,xy,sx(:j-1),sy(:j-1),gsOpts)   ; whole line  

         if (theta(i).lt.170.) then
             gsn_polyline (wks,xy,sx(1:j-1),sy(1:j-1),gsOpts); label room  
             ylab  = skewty(lendth(i)+5.)
            ;t     = THERMO::tda(theta(i),lendth(i)+5.)
             t     = tda_skewt(theta(i),lendth(i)+5.)
             xlab  = skewtx(t,ylab)
             label = floattointeger(theta(i))
             gsn_text(wks,xy,label,xlab,ylab,txOpts)
         else                                               ; no laabel
             gsn_polyline (wks,xy,sx(:j-1),sy(:j-1),gsOpts) ; whole line
         end if

      end do        ; end "i=0,ntheta-1
      delete (gsOpts)
      delete (txOpts)
  end if    ; DryAdiabat

; --- draw moist adiabats up to 230 [was 250] mb.
; --- draw the lines.  iterate in 10 mb increments from 1060 mb.

  if (localOpts@DrawMoistAdiabat) then
      gsOpts                   = True 
      gsOpts@gsLineColor       = colGreen     
      gsOpts@gsLineThicknessF  = 4.0
      gsOpts@gsLineDashPattern = 0            

      txOpts                   = True
      txOpts@txAngleF          = 0.
      txOpts@txFontColor       = colGreen
      txOpts@txFontHeightF     = 0.0125
      txOpts@txFontThicknessF  = 1.0

      pinc = 10.

      do i=0,npseudo-1
         p = 1060.
         do j=0,dimsizes(sy)-1
            p = p-pinc
            if (p.lt.230.) then      ; was "250"
                break
            end if
            sy(j) = skewty(p)
           ;t     = THERMO::satlft(pseudo(i),p)    ; temp on moist adiabat at p
            t     = satlft_skewt(pseudo(i),p)      ; temp on moist adiabat at p
            sx(j) = skewtx(t,sy(j))
           ;print ("j="+j+"  p="+p+"  t="+t+"   sy(j)="+sy(j)+"  sx(j)="+sx(j) )  
         end do            ; end "j=0,dimsizes(sy)-1"

         gsn_polyline (wks,xy,sx(:j-1),sy(:j-1),gsOpts)  

         ylab  = skewty(p+0.5*pinc)
        ;t     = THERMO::satlft(pseudo(i),p+0.75*pinc)
         t     = satlft_skewt(pseudo(i),p+0.75*pinc)
         xlab  = skewtx(t,ylab)
         label = floattointeger(pseudo(i))        ; 9 Feb 99 fix 
         gsn_text(wks,xy,label,xlab,ylab,txOpts)
  
      end do               ; end "i-0,dimsizes(pseudo)-1"
      delete (gsOpts)
      delete (txOpts)
  end if    ; DrawMoistAdiabat

  if (localOpts@DrawStandardAtm) then
      gsOpts                   = True 
      gsOpts@gsLineColor       = colTan   
      gsOpts@gsLineThicknessF  = localOpts@DrawStandardAtmThk
      gsOpts@gsLineDashPattern = 0            
    
      do i=0,nlvl-1
         sy(i) = skewty (psa(i))
         sx(i) = skewtx (tsa(i), sy(i) )
      end do
 
      gsn_polyline (wks,xy,sx(0:nlvl-1),sy(0:nlvl-1),gsOpts)  
      delete (gsOpts)
  end if    ; DrawStandardAtm

; --- draw vertical line upon which to plot wind barbs.

  if (localOpts@DrawWind) then
      gsOpts = True 
      gsOpts@gsLineColor       = "Foreground"     
      gsOpts@gsLineThicknessF  = 1.0
      gsOpts@gsLineDashPattern = 0            
      gsOpts@gsMarkerIndex     = 4   ; "hollow_circle"=> std pres
      gsOpts@gsMarkerColor     = "Foreground"

      presWind      = pres
      presWind(0)   = 1013.          ; override 1050
      xWind         = skewtx (45. , skewty(presWind(0)))
      sx(0:npres-1) = xWind            ; "x" location of wind plot
      sy(0:npres-1) = skewty(presWind)
      gsn_polyline   (wks,xy,sx(0:npres-1),sy(0:npres-1),gsOpts)  
;;;JACK-line_only      gsn_polymarker (wks,xy,sx(1:npres-1),sy(1:npres-1),gsOpts)
;;;JACK-line_only                                     ; zwind => Pibal reports
;;;JACK-line_only      zftWind = (/ 0., 1., 2., 3., 4., 5., 6., 7., 8., 9., 10. \
;;;JACK-line_only                 ,12.,14.,16.,18.,20.,25.,30.,35.,40.,45.,50. /)
;;;JACK-line_only      zkmWind = zftWind*f2m
;;;JACK-line_only      pkmWind = ftcurv(zsa,psa,zkmWind)
;;;JACK-line_only      nzkmW   = dimsizes (zkmWind)
;;;JACK-line_only      sx(0:nzkmW-1)            = xWind  ; "x" location of wind plot
;;;JACK-line_only      sy(0:nzkmW-1)            = skewty(pkmWind)
;;;JACK-line_only      gsOpts@gsMarkerIndex     = 16     ; "circle_filled" -> Pibal
;;;JACK-line_only      gsOpts@gsMarkerSizeF     = 0.0035 ; 0.007 is default
;;;JACK-line_only      gsOpts@gsMarkerThicknessF= 0.5    ; 1.0 is default
;;;JACK-line_only      gsn_polymarker (wks,xy,sx(0:nzkmW-1),sy(0:nzkmW-1),gsOpts)
      delete (gsOpts)
  end if    ; DrawWind


  return (xy)      ; return object

  end

;=========================================================================================

function skewT_PlotData (wks:graphic, skewt_bkgd:graphic \
                        ,P[*]:numeric,TC[*]:numeric      \
                        ,TDC[*]:numeric,Z[*]:numeric     \
                        ,WSPD[*]:numeric,WDIR[*]:numeric \
;;;JACK - add plot of QCLOUD,CLDFRA
                        ,QCLOUD[*]:numeric \
                        ,CLDFRA[*]:numeric \
;;;JACK - add plot of surface T and Td as dots
                        ,sfcpmb:numeric,sfctc:numeric,sfctd:numeric \
;;;JACK - add plot of 10m windspeed as dot                        ,ws10m:numeric \
                        ,dataOpts:logical                )
 begin
                        ; determine index of non-msg values
                        ; used in plotting the sounding and
                        ; calculating thermodynamic quantities

;;;JACK - allow control over P used for top of plot = Ptop
;;; must set Ptop in both skewT_BackGround and skewT_PlotData
Ptop = 250. 

;;;JACK - this deletes pts above Ptop, so sounding line ends before plot top
;;;JACK - allow control over P used for top of plot = Ptop
  idx = ind (.not.ismissing(P)   .and. .not.ismissing(TC)  .and. \
             .not.ismissing(TDC) .and. P.ge.Ptop )
  ;old       .not.ismissing(TDC) .and. P.ge.100. )

  p   = P(idx)          ; transfer non-msg values to local arrays
  tc  = TC(idx)         ; *generally* these local arrays are used
  tdc = TDC(idx)
;;;JACK - ADD LHS PLOT OF CLOUD MIXING RATIO - must use local array to allow for missing value treatment
  qcloud = QCLOUD(idx)
;;;JACK - ADD LHS PLOT OF CLOUD FRACTION - must use local array to allow for missing value treatment
  cldfra = CLDFRA(idx)
 ;print (" non-msg:  p="+p+"  tc="+tc+"  tdc="+tdc+ \
 ;       " other     Z="+Z(idx)+"  WSPD="+WSPD(idx)+"  WDIR="+WDIR(idx) )
  localOpts           = True     ; options describing data and ploting
  localOpts@PrintZ    = True     ; print geopotential (Z) on skewT diagram
  localOpts@PlotWindP = True     ; plot wind barbs at p lvls
  localOpts@WspdWdir  = True     ; wind speed and dir [else: u,v]
  localOpts@PlotWindH = False    ; plot wind barbs at h lvls [pibal; special]
  localOpts@HspdHdir  = True     ; wind speed and dir [else: u,v]
  localOpts@ThermoInfo= True     ; print thermodynamic info
  localOpts@Cape      = True     ; plot CAPE parcel profile if cape>0
;  localOpts@Parcel    = 0        ; subscript corresponding to initial parcel
;  localOpts@Cape      = False     ; plot CAPE parcel profile when cape>0
  localOpts@Parcel    = 0        ; subscript corresponding to initial parcel
  localOpts@PlotTKE  = False     ; instead plot cldfra
                                 ; Override the default localOpts
                                 ; with input dataOpts
  if (dataOpts .and. .not.any(ismissing(getvaratts(dataOpts)))) then
      localAtts = getvaratts(localOpts)
      dataAtts  = getvaratts(dataOpts)
      nOpts     = dimsizes  (dataAtts)
      do i=0,nOpts-1
         if (any(dataAtts(i).eq.localAtts)) then
             localOpts@$dataAtts(i)$ = dataOpts@$dataAtts(i)$
         end if 
      end do
  end if

  getvalues skewt_bkgd
     "vpXF"                  : vpXF
     "vpYF"                  : vpYF
     "vpWidthF"              : vpWidthF
     "vpHeightF"             : vpHeightF
     "tiMainFont"            : tiMainFont
     "tiMainFontHeightF"     : tiMainFontHeightF
     "tiMainOffsetXF"        : tiMainOffsetXF 
     "tmYLLabelFontHeightF"  : tmYLLabelFontHeightF
  end getvalues
                                          ; assorted color 'indices'
  colForeGround = "Foreground"
  colTemperature = "Red"
  ;original colTemperature = "Foreground"
  colDewPt      = "RoyalBlue"
  colCape       = "Magenta"
  ;original colCape       = "Red"
  colZLabel     = "Foreground"
  colWindP      = "Black"                 ; [Not Yet]
  colWindZ      = "RoyalBlue"             ; [Not yet]          
  colWindH      = "DarkMagenta"           ; [Not yet] H wind barbs different
  colThermoInfo = "Sienna"
  WScolLo       = (/ 0.1, 0.75, 0.1 /) ; "Green"
  WScolHi       = (/ 1.0, 0.0,  0.0 /) ; "Red"
                                          ; gs settings for gsn_polyline
  gsOpts                   = True
  gsOpts@gsLineDashPattern = 0            ; solid
  ;;; controls thickness of sounding T,Td lines
  gsOpts@gsLineThicknessF  = 8.0
  yp   = skewty (p)                    
  xtc  = skewtx (tc , yp)              ; T-P plot
  gsOpts@gsLineColor  = colTemperature   
  gsn_polyline  (wks,skewt_bkgd,xtc ,yp,gsOpts) 
  xtdc = skewtx (tdc, yp)              ;Dew Pt-P plot
  gsOpts@gsLineColor  = colDewPt     
  gsn_polyline  (wks,skewt_bkgd,xtdc,yp,gsOpts) 
  ;;;JACK - add plot of surface T and Td as dots
  ;bad=>gcc4_optimization_failure  gsOpts@gsMarkerIndex = NhlNewMarker(wks, "Z",37, 0.,0.,1.3125, 0.6, 0.)  ; smaller solid circle
  ;old-bad workaround for gcc4_optimization_failure of smaller solid circle - per http://www.ncl.ucar.edu/Support/talk_archives/2007/0366.html  
  yp  = skewty(sfcpmb-0.2)          ; for 2m height                    
  gsOpts@gsMarkerIndex     = 16     ; solid circle
  gsOpts@gsMarkerSizeF     = 0.007  ; default=0.007
  gsOpts@gsMarkerColor     = colTemperature
  gsn_polymarker (wks,skewt_bkgd, skewtx(sfctc,yp),yp, gsOpts)
  gsOpts@gsMarkerColor     = colDewPt
  gsn_polymarker (wks,skewt_bkgd, skewtx(sfctd,yp),yp, gsOpts)
  delete (gsOpts)

  if (localOpts@ThermoInfo) then
      nP   = localOpts@Parcel  ; default is the lowest level [0]
      nlvls= dimsizes(p)
      plcl = -999.             ; p (hPa) Lifting Condensation Lvl (lcl)
      tlcl = -999.             ; temperature (C) of lcl
     ;THERMO::ptlcl(p(nP),tc(nP),tdc(nP),plcl,tlcl)
      ptlcl_skewt(p(nP),tc(nP),tdc(nP),plcl,tlcl)
     ;shox = THERMO::showal(p,tc,tdc,nlvls)   ; Showwalter Index
      shox = showal_skewt(p,tc,tdc)           ; Showwalter Index
     ;pwat = THERMO::precpw(tdc,p,nlvls)      ; precipitable water (cm)
      pwat = pw_skewt(tdc,p)                  ; precipitable water (cm)
      iprnt= 0                                ; debug only (>0)
      nlLcl= 0                                
      nlLfc= 0
      nlCross= 0
     ;cape = THERMO::cape_ncl(p,tc,nlvls,plcl,iprnt,tpar,tmsg \
     ;                       ,nlLcl,nlLfc,nlCross)
      cape = cape_thermo(p,tc,plcl,iprnt)
      tpar = cape@tparcel
      nlLcl= cape@jlcl
      nlLfc= cape@jlfc
      nlCross= cape@jcross
                                              ; 0.5 is for rounding
      info = " Plcl="    +floattointeger(plcl+0.5) \ 
           + " Tlcl[C]=" +floattointeger(tlcl+0.5) \
           + " Shox="    +floattointeger(shox+0.5) \
           + " Pwat[cm]="+floattointeger(pwat+0.5) \
           + " Cape[J]= "+floattointeger(cape)

      txOpts                   = True
      txOpts@txAngleF          = 0.
      txOpts@txFont            = tiMainFont
      txOpts@txFontColor       = colThermoInfo
      ;;;JACK - increase height of sounding info text
      txOpts@txFontHeightF     = 0.6*tiMainFontHeightF
      ;original txOpts@txFontHeightF     = 0.5*tiMainFontHeightF
      xinfo                    = vpXF  + 0.5*vpWidthF + tiMainOffsetXF
      yinfo                    = vpYF  + 0.5*tiMainFontHeightF 
      gsn_text_ndc (wks,info,xinfo,yinfo,txOpts) 
      delete (txOpts)

;;;JACK - START OF ADDED LHS PLOT OF CLOUD FRACTION
      ;;; start of line plot
      ;;; skip when cldfra<0
      if( cldfra(0) .ge. 0.0 ) then
        cldfracolor = "black"
        gsOpts                   = True
        gsOpts@gsLineColor       = cldfracolor
        gsOpts@gsLineDashPattern = 0         ; 0=solid  1=dash        
        gsOpts@gsLineThicknessF  = 4.0
        yp   = skewty (p)                    
        ;NB - formula used here must match that used for maximum scale line below
        cldfra = 4.*cldfra -19.0 
        gsn_polyline  (wks,skewt_bkgd, cldfra, yp, gsOpts) 
        ;;;;;; start of labelplot - must be ndc to print above plot perimeter
        ;fraction 
        cldfratickinc = 0.5
        ;yes-no cldfratickinc = 1.0
        if ( .not. localOpts@PlotTKE) then
          info = "Grid-Scale Cloudiness"
        else
          info = "Turbulent KE (m^2/s^2)"
        end if
        ;old info = "Grid-Scale Cloud"
        ;old info = "Grid-Scale Cloud Fraction"
        ;older info = "Cloud Fraction"
        txOpts                   = True
        txOpts@txAngleF          = 0.
        txOpts@txFont            = tiMainFont
        txOpts@txFontColor       = cldfracolor
        txOpts@txFontHeightF     = 0.6*tiMainFontHeightF
        xinfondc                    = vpXF +0.157
        ;;; set y location for bottom label+ticks - plot outside skewt outline
        yndc                    = vpYF - vpHeightF - 0.55*tiMainFontHeightF 
        gsn_text_ndc (wks,info,xinfondc,yndc,txOpts) 
        ;;; loop over top & bottom label+ticks
        do ii=1,2
          ;;; plot tick labels
          xndc = 0.0         ; dummy value needed to avoid UIV bomb
          dummy = 0.
          ;fraction
          do itick=0,2
            ;yes-no do itick=0,1
            tickvalue = itick*cldfratickinc
            ;NB - formula used here must match that used for actual data above
            xtick = 4.*tickvalue -19.0 
            ;fraction 
            tickstring = sprintf( "%3.1f", tickvalue )
            ;yes-no if( itick .eq. 0 ) then
            ;yes-no   tickstring = "No"
            ;yes-no else
            ;yes-no   tickstring = "Yes"
            ;yes-no end if
            datatondc( skewt_bkgd, xtick,0., xndc,dummy )
            gsn_text_ndc (wks,tickstring,xndc,yndc,txOpts) ; plots at center x-wise
          end do
          ;;; set y location for top label+ticks - plot inside skewt outline
          yndc                    = vpYF  - 0.5*tiMainFontHeightF 
        end do
        delete (gsOpts)
        delete (txOpts)
      end if
      delete (cldfra )
;;;JACK - END OF ADDED LHS PLOT OF CLOUD FRACTION
;;;JACK - START OF ADDED LHS PLOT OF CLOUD MIXING RATIO
      ;;; start of line plot
      qcloudcolor = (/0.1, 0.75, 0.1 /)  ;"green"
      ;old qcloudcolor = "blue"
      gsOpts                   = True
      gsOpts@gsLineColor       = qcloudcolor
      gsOpts@gsLineDashPattern = 0         ; 0=solid  1=dash        
      gsOpts@gsLineThicknessF  = 4.0
      yp   = skewty (p)                    
      ;NB - formula used here must match that used for maximum scale line below
      qcloud = 4000.*qcloud -19.0 
      ;old-max=2 qcloud = 2000.*qcloud -19.0 
      gsn_polyline  (wks,skewt_bkgd, qcloud, yp, gsOpts) 
      ;;;;;; start of labelplot - note are plotted in ndc
      qcloudtickinc = 0.5
      ;old-max=2 qcloudtickinc = 0.001
      info = "CloudWater (g/Kg)"
      txOpts                   = True
      txOpts@txAngleF          = 0.
      txOpts@txFont            = tiMainFont
      txOpts@txFontColor       = qcloudcolor
      txOpts@txFontHeightF     = 0.6*tiMainFontHeightF
      xinfondc                     = vpXF +0.145
      ;;; set y location for bottom label+ticks - plot inside skewt outline
      yndc                    = vpYF - vpHeightF + 0.35*tiMainFontHeightF 
      gsn_text_ndc (wks,info,xinfondc,yndc,txOpts) 
      ;;; loop over top & bottom label+ticks
      do ii=1,2
        ;;; plot tick labels
        xndc = 0.0         ; dummy value needed to avoid UIV bomb
        dummy = 0.
        do itick=0,2
          tickvalue = itick*qcloudtickinc
          ;NB - formula used here must match that used for actual data above BUT WITH FACTOR 0.001 DUE TO TICK LABEL IN gm/kg
          xtick = 4.*tickvalue -19.0 
          tickstring = sprintf( "%3.1f", tickvalue )
          datatondc( skewt_bkgd, xtick,0., xndc,dummy )
          ;;; set y location for bottom label+ticks
          gsn_text_ndc (wks,tickstring,xndc,yndc,txOpts) ; plots at center x-wise
        end do
        ;;; set y location for top label+ticks - plot outside  skewt outline
        yndc                     = vpYF  + 0.5*tiMainFontHeightF 
      end do
      delete (qcloud )
      delete (gsOpts)
      delete (txOpts)
;;;JACK - END OF ADDED LHS PLOT OF CLOUD MIXING RATIO

      if (localOpts@Cape .and. cape.gt.0.) then
          gsOpts                   = True
          gsOpts@gsLineColor       = colCape   
          gsOpts@gsLineDashPattern = 1         ; 14          
;;;JACK -  ALSO AFFECTS THICKNESS OF WIND VECTOR PLOT IN ORIGINAL CODE !!! 
;;;        so added extra ployline plot prior to windbarb plot to re-set gsOpts
          gsOpts@gsLineThicknessF  = 4.0
         ;original          gsOpts@gsLineThicknessF  = 2.0
          yp   = skewty (p)                    
          xtp  = skewtx (tpar, yp)
          gsn_polyline  (wks,skewt_bkgd,xtp(nlLfc:nlCross)       \
                                       , yp(nlLfc:nlCross),gsOpts) 
          delete (gsOpts)
      end if

  end if    ; ThermoInfo

  if (localOpts@PrintZ) then           ; print geopotential (?)
      txOpts               = True
      txOpts@txAngleF      = 0.
      txOpts@txFontColor   = colZLabel
      txOpts@txFontHeightF = 0.9*tmYLLabelFontHeightF
                                       ; levels at which Z is printed
      Pprint = (/1000., 850., 700., 500., 400., 300. \
               ,  250., 200., 150., 100. /)

      yz = skewty (1000.) 
      xz = skewtx (-30., yz)           ; constant "x"
      do nl=0,dimsizes(P)-1            ; use input arrays
         if (.not.ismissing(P(nl)) .and. .not.ismissing(Z(nl)) .and. \
             any(Pprint.eq.P(nl))) then
             yz  = skewty (P(nl)) 
             gsn_text (wks,skewt_bkgd,floattointeger(Z(nl)) \
                          ,xz,yz,txOpts) 
         end if
      end do          ; nl
      delete (txOpts)
  end if

  if (localOpts@PlotWindP) then
      gsOpts                   = True
;;;JACK -  does _not_ affect thickness of wind vector plot in original code
      gsOpts@gsLineThicknessF  = 2.0
;;;JACK - START OF KLUDGE to get thin windbarbs, by adding dummy ployline plot prior to windbarb plot to re-set gsOpts 
         xx    = new (  2, float)
         yy    = new (  2, float)
         xx(0) = 0.0
         xx(1) = 0.0
         yy(0) = 0.0
         yy(1) = 0.0
         gsn_polyline  (wks,skewt_bkgd,xx,yy,gsOpts) 
         delete(xx)
         delete(yy)
;;;JACK - END OF KLUDGE
;;;JACK - this deletes pts above Ptop, so sounding line ends before plot top
;;;JACK - allow control over P used for top of plot = Ptop
      if (.not.all(ismissing(WSPD))) then
          ;old  idw = ind (.not.ismissing(P)    .and. P.ge.100. .and.     
          idw = ind (.not.ismissing(P)    .and. P.ge.Ptop .and.     \
                     .not.ismissing(WSPD) .and. .not.ismissing(WDIR) )
          pw  = P(idw)   
          if (localOpts@WspdWdir) then      ; wind spd,dir (?)
              dirw = 0.017453*WDIR(idw)
              up   = -WSPD(idw)*sin(dirw)
              vp   = -WSPD(idw)*cos(dirw)
;;;JACK - ADD WINDSPEED PLOT
              ws = WSPD(idw)
          else
              up   = WSPD(idw)              ; must be u,v components
              vp   = WDIR(idw)
;;;JACK - ADD WINDSPEED PLOT
              ws = sqrt( WSPD(idw)^2+WDIR(idw)^2 )
          end if
         ;4testprint print( "> WINDSPEED CALC: "+idw+" "+pw+" "+ws )   
         ;wbcol = wmgetp("col")             ; get current wbarb color
         ;wmsetp("col",colWindP)            ; set new color index
          ypWind = skewty (pw) 
          xpWind = new (dimsizes(pw), float)
          xpWind = skewtx (45. , skewty(1013.) ) ; location of wind barb
         ;;; for metric, the "standard" is for wind speed barbs to still be plotted in kts 
         if( dataOpts@units .eq. "metric" ) then
                up = 1.94384 * up
                vp = 1.94384 * vp
         end if
          wmbarb(wks, xpWind, ypWind, up, vp )
         ;wmsetp("col",wbcol)               ; reset to initial color value 
         ;4testprint    print( "--- PlotWindP windbarbs plotted" )   

;;;JACK - START OF ADDED WINDSPEED PLOT (note hardwiring here assumes fixed skewt boundary including height axis)
      ;;; start of line plot
      max_ws = max(ws)
      ;;; use fixed windspeed ranges: low,high = green,red - each is double that of previous
      wscolor = WScolLo         ; for low-speed wind range
      ;old=3level wscolor = "blue"         ; for low-speed wind range
      if( dataOpts@units .ne. "metric" ) then
        info = "Speed (kt)"
        wstickinc =  20.        ; for low-speed wind range
        wsplotfactor = 0.15     ; for low-speed wind range
        ;old=3level wstickinc =  10.        ; for low-speed wind range
        ;old=3level wsplotfactor = 0.30     ; for low-speed wind range
      else
        info = "Speed (m/s)"
        wstickinc =  10.        ; for low-speed wind range
        wsplotfactor = 0.30     ; for low-speed wind range
        ;old=3level wstickinc =   5.        ; for low-speed wind range
        ;old=3level wsplotfactor = 0.60     ; for low-speed wind range
      end if
      ;;; maximum plot-able windspeed ~3.62*wstickinc but allow some margin !
      ;old=3level ;;; when necessary, use medium-speed wind increment
      ;old=3level if( max_ws .gt. (3.0*wstickinc) ) then
      ;old=3level   wscolor = "green"
      ;old=3level   wscolor = "green"
      ;old=3level   wstickinc = 2.0 * wstickinc
      ;old=3level   wsplotfactor = 0.5 * wsplotfactor
      ;old=3level end if
      ;;; when necessary, use high-speed wind increment
      if( max_ws .gt. (3.0*wstickinc) ) then
        wscolor = WScolHi
        wstickinc = 2.0 * wstickinc
        wsplotfactor = 0.5 * wsplotfactor
      end if
      gsOpts                   = True
      gsOpts@gsLineColor       = wscolor
      gsOpts@gsLineDashPattern = 0         ; 0=solid  1=dash        
      gsOpts@gsLineThicknessF  = 4.0
      yp   = skewty (pw)                    
      xWind         = skewtx (45. , skewty(1013.))
      x_ws = xWind + wsplotfactor*ws 
      ;old x_ws = xWind +0.075*ws 
      ;old ;;;JACK - gsn_polyline clips windspeed line at left axis 
      ;old gsn_polyline  (wks,skewt_bkgd, x_ws, yp, gsOpts) 
      ;didntwork ;;;JACK - tried to use gsn_polyline_ndc to get eliminate clipping at left axis but still clipped even when use manual conversion !?
      ; need to create new arrays of correct size
      x_ndc = x_ws
      y_ndc = yp
      do ii=0,(dimsizes(x_ndc)-1)
        ;;; must use manual conversion of ws to ndc x to allow plotting outside viewport boundary (ok since xmin,xmax should not change)
        ;;;   since datatondc gives "missing value" (1e+30) for both x&y when x outside viewport 
        ;;;   but must use datatondc for y to allow for possible change in Ptop (use x=0 in call to ensure not outside viewport)
        datatondc( skewt_bkgd, 0.,yp(ii), x_ndc(ii),y_ndc(ii) )
        x_ndc(ii) = 0.3991200 + 0.01732290 * x_ws(ii)
        ;4test: print ( "X=>NDC: "+ii+" x_ws,x_ndc= "+x_ws(ii)+","+x_ndc(ii) )
        ;4test:  print ( "Y=>NDC: "+ii+" yp,y_ndc= "+yp(ii)+","+y_ndc(ii) )
        ;4testprint print( "> WINDSPEED PLOT: "+ii+" "+P(ii)+" "+x_ws(ii)+" "+yp(ii)+" => "+ x_ndc(ii)+" "+y_ndc(ii) )   
      end do      
      gsn_polyline_ndc ( wks, x_ndc, y_ndc, gsOpts ) 
      ;;;;;; start of labelplot - note this not plotted in ndc whereas similar qvapor label is 
      txOpts                   = True
      txOpts@txAngleF          = 0.
      txOpts@txFont            = tiMainFont
      txOpts@txFontColor       = wscolor
      txOpts@txFontHeightF     = 0.6*tiMainFontHeightF
      xinfo                    = .87
      ;;; set y location for bottom label+ticks
      yinfo                    = vpYF - vpHeightF - 0.65*tiMainFontHeightF 
      ytick                    = skewty(985.)-0.9
      gsn_text_ndc (wks,info,xinfo,yinfo,txOpts) 
      ;;; loop over top & bottom label+ticks
      do ii=1,2
        ;;; plot tick labels
        do itick=0,3
          qwstick = itick*wstickinc
          ;NB - eqn used here must match that used for actual data above
          x_wstick = xWind + wsplotfactor*qwstick
          ;old x_wstick = xWind +0.075*qwstick
          ;extrawide=56.10
          x_ndc = 0.3991200 + 0.01732290 * x_wstick 
          y_ndc = 0.0926626 + 0.0188905 * ytick
          ;older(extrawide=55) x_ndc(ii) = 0.403166 + 0.01753466 * x_wstick 
          tickstring = sprinti( "%d", floattointeger(qwstick) )
          gsn_text_ndc (wks,tickstring,x_ndc,y_ndc,txOpts) ; plots at center x-wise
          ;old gsn_text (wks,skewt_bkgd,tickstring,xinfo,yinfo,txOpts) ; plots at center x-wise
        end do
        ;;; set y location for top label+ticks
        yinfo                    = vpYF  + 0.5*tiMainFontHeightF 
        ytick                    = skewty(98.)-0.9
      end do
      delete (ws)
      delete (txOpts)
;;;JACK - END OF ADDED WINDSPEED PLOT
      ;;;JACK - removed plot of 10m windspeed since is at 10m not really "surface" so might be misleading as temp/dp dots are at 2m
      ; ;;;JACK - add plot of 10m windspeed as dot
      ; yp  = skewty(sfcpmb-1.0)          ; for 10m height                    
      ; gsOpts@gsMarkerIndex     = 16     ; solid circle
      ; gsOpts@gsMarkerSizeF     = 0.005  ; default=0.007
      ; gsOpts@gsMarkerColor     = wscolor
      ; x_ws = xWind + wsplotfactor*ws10m 
      ; gsn_polymarker (wks,skewt_bkgd, x_ws,yp, gsOpts)
      delete (gsOpts)

                                            ; chk for soundings where Z/wind
                                            ; were merged but no pressure
          idz = ind ( ismissing(P) .and.  .not. ismissing(Z) .and.   \
                     .not.ismissing(WSPD) .and. .not.ismissing(WDIR) )
          if (.not.ismissing(idz)) then
              zw  = Z(idz)   
              if (localOpts@WspdWdir) then      ; wind spd,dir (?)
                  dirz = 0.017453*WDIR(idz)
                  uz   = -WSPD(idz)*sin(dirz)
                  vz   = -WSPD(idz)*cos(dirz)
              else
                  uz   = WSPD(idz)              ; must be u,v components
                  vz   = WDIR(idz)
              end if
                                                ; idzp=indices non-msg Z and P
              idzp = ind (.not.ismissing(P) .and. .not.ismissing(Z))
              pz   = ftcurv (Z(idzp),P(idzp),zw)  ; map zw to p levels

             ;wbcol = wmgetp("col")             ; get current wbarb color
             ;wmsetp("col",colWindZ)            ; set new color index
                                                ; see skewT_BackGround
              yzWind = skewty (pz) 
              xzWind = new (dimsizes(pz), float)
              xzWind = skewtx (45. , skewty(1013.) ) ; location of wind barb
              ;;; for metric, the "standard" is for wind speed barbs to still be plotted in kts 
              if( dataOpts@units .eq. "metric" ) then
                uz = 1.94384 * uz
                vz = 1.94384 * vz
              end if
              wmbarb(wks, xzWind, yzWind, uz, vz )
             ;wmsetp("col",wbcol)               ; reset to initial color value 
             ;4testprint    print( "--- ?merged? windbarbs plotted" )   

          end if   ; end ".not.ismissing(idz)"
      end if       ; end ".not.all(ismissing(WSPD))"
  end if           ; end "PlotWindP"
                                                ; SPECIAL SECTION [IGNORE]
                                                ; allows 'other' winds to be
                                                ; input as attributes of sounding
  if (localOpts@PlotWindH) then
;;;JACK inserting 2 lines below does not affect thickness of wind vector plot
      gsOpts                   = True
      gsOpts@gsLineThicknessF  = 1.0
;;;JACK - START OF KLUDGE to get thin windbarbs, by adding dummy ployline plot prior to windbarb plot to re-set gsOpts 
         xx    = new (  2, float)
         yy    = new (  2, float)
         xx(0) = 0.0
         xx(1) = 0.0
         yy(0) = 0.0
         yy(1) = 0.0
         gsn_polyline  (wks,skewt_bkgd,xx,yy,gsOpts) 
         delete(xx)
         delete(yy)
;;;JACK - END OF KLUDGE
      if (isatt(dataOpts,"Height") .and. isatt(dataOpts,"Hspd") \
                                   .and. isatt(dataOpts,"Hdir") ) then
          dimHeight = dimsizes(dataOpts@Height)
          dimHspd   = dimsizes(dataOpts@Hspd  )
          dimHdir   = dimsizes(dataOpts@Hdir  )
          if (dimHeight.eq.dimHspd .and. dimHeight.eq.dimHdir .and. \
              .not.all(ismissing(dataOpts@Height))) then
              if (localOpts@HspdHdir) then      ; wind spd,dir (?)
                  dirh= 0.017453*dataOpts@Hdir
                  uh  = -dataOpts@Hspd*sin(dirh)
                  vh  = -dataOpts@Hspd*cos(dirh)
              else
                  uh  = dataOpts@Hspd           ; must be u,v components
                  vh  = dataOpts@Hdir
              end if  ; end "localOpts@HspdHdir"

              idzp = ind (.not.ismissing(P) .and. .not.ismissing(Z))
              ph   = ftcurv (Z(idzp),P(idzp),dataOpts@Height) ; Height to p levels

             ;wbcol = wmgetp("col")             ; get current color index
             ;wmsetp("col",colWindH)            ; set new color index

              yhWind = skewty (ph) 
              xhWind = new (dimsizes(ph), float)
              xhWind = skewtx (45. , skewty(1013.) ) ; location of wind barb
              ;;; for metric, the "standard" is for wind speed barbs to still be plotted in kts 
              if( dataOpts@units .eq. "metric" ) then
                uh = 1.94384 * uh
                vh = 1.94384 * vh
              end if
              wmbarb(wks, xhWind, yhWind, uh, vh )
             ;wmsetp("col",wbcol)               ; reset to initial color value 
             ;4testprint    print( "--- PlotWindH windbarbs plotted" )   

          end if
      else
          print ("Opts@PlotWindH=True but dataOpts@Height/Hspd/Hdir msg")
      end if
  end if  ; end "PlotWindH"

  return (skewt_bkgd)

 end
