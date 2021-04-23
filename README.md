# RASP from scratch

This repo provides Dockerfiles that help in the creation of a production-ready container image for running RASP forecasts.
Contrary to most other available setups, WRF is built from scratch.

## Build

The process of building the final image is somewhat complicated as we do not want to bloat the image size.
Therefore, the build happens in 3 stages.

#### Build base image

```shell
$ cd base
$ docker build -t <base tag> .
```

This image is based on a current Fedora Linux image and adds common utilities and libraries.

#### Build WRF

```shell
$ cd wrf
$ docker build -t <wrf tag> .
```

In this step, WRF and WPS are fetched from GitHub and compiled from source.
This can take a long time, so be patient and do not worry about the verbose output!
We use some of DrJack's patches to change WRF's registry, so that all needed variables are output.
Note however, that the custom cloud calculation patches are not applied!
WRF will be compiled with GNU compilers in smpar (i.e. OpenMP) mode (compilation option 33) and with basic nesting support (nesting option 1).

**The binaries are only guaranteed to run on your system** because the compiler options `-march=native -mtune=native` are used.
If cross-compatible binaries are needed, change the optimization flags in the provided patch file `configure.wrf.patch` to something more explicit that is targeted to the machines you intend to run WRF on.

#### Build RASP

**You will need geographical data in `rasp/geog.tar.gz` before you run this step!**
Go to [UCAR's page](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html) and download the appropriate bundle.

```shell
$ cd rasp
$ docker build -t <rasp tag> .
```

This sets up the directory structure for RASP runs, copies all the run and plotting scripts, copies the necessary binaries and run tables from the WRF image, sets up the RASP region and runs `geogrid.exe` on it.
Finally, in a second build stage, only the necessary artifacts are copied over from the first stage so that the final image remains at an optimal size.

### Adapt to your own region

You can easily provide your own region by modifying the contents of `TIR` (which is the region I use).
Remember to also change some region specific aspects of the NCL scripts located in `rasp/GM` and update `GM.tar.gz` afterwards via `tar czf GM.tar.gz GM`.

You need the following in your region folder:
 - `namelist.wps` and `namelist.wps.template` (identical) for WPS
 - `namelist.input` and `namelist.input.template` (identical) for WRF
 - A symlink named `Vtable` to the Variable Table filename you want to use for your GRIB files, e.g. for GFS: `ln -s Vtable.GFS Vtable`. The actual table file does not have to exist on your host machine, it will be provided by the WRF image during build time.

If you use non-stock geog data (e.g. SRTM):
 - Your custom `GEOGRID.TBL`

Note that you can provide any custom tables that WRF/WPS recognizes; the respective stock version will be overwritten in the docker build process.

## Run 

In the base directory:

```shell
$ docker-compose run
```

If you want to start this process in the background, append `-d`.
For an interactive container, append `/bin/bash`. When the container is running, execute `runRasp.sh <region> &` to start the RASP run for your `<region>`.
