#!/bin/sh

awk '{
v += gsub(/ -O /, " ");
v += sub(/-I\$\(NETCDF\)\/include/, "-I$(NETCDF)/include -I/usr/lib64/gfortran/modules");
v += sub(/-L\$\(NETCDF\)\/lib/, "-L$(NETCDF)/lib -L/usr/lib64 -lnetcdff -fopenmp");
print
}
END{ if(v!=4) exit 1 }' configure.wps > newconfigure.wps

sed -i "s/jpc_encode(&image,jpcstream,opts)/jas_image_encode(&image,jpcstream,jas_image_getfmt(jpcstream),opts)/" ungrib/src/ngl/g2/enc_jpeg2000.c

sed -i "s/jpc_decode(jpcstream,opts)/jas_image_decode(jpcstream,jas_image_getfmt(jpcstream),opts)/" ungrib/src/ngl/g2/dec_jpeg2000.c

if [ $? -eq 0 ]
then
	echo "Successfully patched configure.wps"
	mv newconfigure.wps configure.wps
else
	echo "Could not apply all patches to configure.wps. This is what could be done:"
	cat newconfigure.wps
	exit 1
fi

