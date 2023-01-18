#!/bin/sh

# first parameter must be the architecture name

OPTFLAGS="-O3 -ftree-vectorize -funroll-loops -ffast-math -flto=auto -march=$1"

awk -v optflags="$OPTFLAGS" '{
v += sub(/^FCOPTIM\s*=.*/, "FCOPTIM = " optflags);
v += sub(/-L\$\(WRF_SRC_ROOT_DIR\)\/external\/io_netcdf/, "-L$(WRF_SRC_ROOT_DIR)/external/io_netcdf -lnetcdf -lnetcdff");
print
}
END{ if(v!=2) exit 1 }' configure.wrf > newconfigure.wrf

if [ $? -eq 0 ]
then
	echo "Successfully patched configure.wrf"
	mv newconfigure.wrf configure.wrf
else
	echo "Could not apply all patches to configure.wrf. This is what could be done:"
	cat newconfigure.wrf
	exit 1
fi
