#!/bin/sh

awk '{
v += sub(/r\s*"tke"/, "rh   \"tke\"");
v += sub(/r\s*"RTHBLTEN"/, "rh   \"RTHBLTEN\"");
v += sub(/r\s*"RQVBLTEN"/, "rh   \"RQVBLTEN\"");
v += sub(/r\s*"RQCBLTEN"/, "rh   \"RQCBLTEN\"");
print
}
END{ if(v!=4) exit 1 }' Registry/Registry.EM_COMMON > newRegistry.EM_COMMON

if [ $? -eq 0 ]
then
	echo "Successfully patched WRF registry"
	mv newRegistry.EM_COMMON Registry/Registry.EM_COMMON
else
	echo "Could not apply all patches to WRF registry. This is what could be done:"
	cat newRegistry.EM_COMMON
	exit 1
fi
