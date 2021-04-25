# RASP from scratch

This repo provides Dockerfiles that help in the creation of a production-ready container image for running RASP forecasts.
Contrary to most other available setups, WRF is built from scratch.

## Build

The building process is somewhat complicated as we do not want to bloat the image size of the final image that will be ready for production.
Therefore, the build happens in 3 separate stages that result in intermediate images.
Adapt the image tags in the Dockerfiles to your needs.

### Build base image

```shell
$ docker build -t <base tag> base
```

This image will be used in the next steps.
It is based on Fedora Linux and adds common utilities and libraries.

### Build WRF

**Change `wrf/configure.wrf.patch` so that the binaries will be compatible with your CPU type!**
You do this by specifying appropriate `-march` and `-mtune` compiler flags, e.g. if you intend to run WRF on Intel Haswell architectures, set `-march=haswell -mtune=haswell` (cf. GNU compiler manual for available options).
If you run WRF on the same machine you use for compilation, set `-march=native -mtune=native`.

```shell
$ docker build -t <wrf tag> wrf
```

WRF and WPS are fetched from GitHub and compiled from source.
This can take a long time, so be patient and do not worry about the verbose output!
WRF will be compiled with GNU compilers in smpar (i.e. OpenMP) mode (compilation option 33) and with basic nesting support (nesting option 1).

We use the bare minimum of DrJack's patches to change WRF's registry, so that certain variables which are needed for the RASP plot routines appear in `wrfout` files.
Note however, that DrJack's cloud calculation patches are not applied and thus, `wrf=CFRAC[L|M|H]` are not available (or wrong)!

### Build RASP

**You will need geographical data in `rasp/geog.tar.gz` before you run this step!**
Go to [UCAR's page](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html) and download the appropriate bundle.

```shell
$ docker build -t <rasp tag> rasp
```

This sets up the directory structure for RASP runs with all necessary binaries and run tables from the WRF image as well as the RASP plotting environment.
Copying the geographical data into the container and unzipping it will take a long time, so please be patient again.
The region is automatically initialized by running `geogrid.exe`.

Finally, in a second build stage, only the necessary artifacts are copied over from the first stage so that the final image remains at an optimal size.

### Adapt to your own region

You can easily provide your own region by modifying the contents of `TIR` (which is the region I use) and rerunning the previous `docker build` command.
Remember to also change some region specific aspects of the NCL scripts located in `rasp/GM`

You need the following in your region folder:
 - `namelist.wps` and `namelist.wps.template` (identical) for WPS
 - `namelist.input` and `namelist.input.template` (identical) for WRF
 - A symlink named `Vtable` to the Variable Table filename you want to use for your GRIB files, e.g. for GFS: `ln -s Vtable.GFS Vtable`. The actual table file does not have to exist on your host machine, it will be provided by the WRF image during build time.

If you use non-stock geog data (e.g. SRTM):
 - Your custom `GEOGRID.TBL`

Note that you can provide any custom tables that WRF/WPS recognizes in your region directory; the respective stock version will be overwritten in the docker build process.

## Run 

```shell
$ docker-compose run rasp
```

`run -d` makes this a background process.
If you want an interactive shell to your container (e.g. for testing), append `/bin/bash`.
When the container is running, execute the entry script `runRasp.sh <region>` to start the RASP run for your `<region>` manually.
