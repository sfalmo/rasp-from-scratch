#!/bin/sh

awk '{
v += sub(/-I\$\(NETCDF\)\/include/, "-I$(NETCDF)/include -I/usr/lib64/gfortran/modules");
v += sub(/-L\$\(NETCDF\)\/lib/, "-L$(NETCDF)/lib -lnetcdff -fopenmp");
print
}
END{ if(v!=2) exit 1 }' configure.wps > newconfigure.wps

if [ $? -eq 0 ]
then
	echo "Successfully patched configure.wps"
	mv newconfigure.wps configure.wps
else
	echo "Could not apply all patches to configure.wps. This is what could be done:"
	cat newconfigure.wps
	exit 1
fi

