;;; Open Workstation for head or side

function openWksHd(plot_param, tail)
begin
	if( FMT .eq. "png" ) then
		wks = create (OutDir + plot_param + tail + ".head") imageWorkstationClass defaultapp
                "wkHeight"          : wkHeight
                "wkWidth"           : wkWidth
                "wkBackgroundColor" : "white"
                "wkForegroundColor" : "black"
                "wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
		end create
	else
		if( FMT .eq. "x11" ) then
			wks = create (plot_param + tail + ".head") xWorkstationClass defaultapp
			"wkHeight"          : wkHeight
			"wkWidth"           : wkWidth
			"wkBackgroundColor" : "white"
			"wkForegroundColor" : "black"
			"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
			end create
		end if
		if( FMT .eq. "ncgm" ) then
			wks = create plot_param ncgmWorkstationClass defaultapp
				"wkMetaName"        : plot_param + tail + "head"
				"wkHeight"          : wkHeight
				"wkWidth"           : wkWidth
				"wkBackgroundColor" : "white"
				"wkForegroundColor" : "black"
				"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
			end create
		end if
	end if
	return(wks)
end

function openWksLb(plot_param, tail, where)
begin
	if( FMT .eq. "png" ) then
		wks = create (OutDir + plot_param + tail + where) imageWorkstationClass defaultapp
			"wkHeight"          : wkHeight
			"wkWidth"           : wkWidth
			"wkBackgroundColor" : "white"
			"wkForegroundColor" : "black"
			"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
		end create
	else
		if( FMT .eq. "x11" ) then
			wks = create (plot_param + tail + where) xWorkstationClass defaultapp
				"wkHeight"          : wkHeight
				"wkWidth"           : wkWidth
				"wkBackgroundColor" : "white"
				"wkForegroundColor" : "black"
				"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
			end create
		end if
		if( FMT .eq. "ncgm" ) then
			wks = create plot_param ncgmWorkstationClass defaultapp
				"wkMetaName"        : plot_param + tail + where
				"wkHeight"          : wkHeight
				"wkWidth"           : wkWidth
				"wkBackgroundColor" : "white"
				"wkForegroundColor" : "black"
				"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
			end create
		end if
	end if
	return(wks)
end

