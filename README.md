# RASP from scratch

This repo provides Dockerfiles that help in the creation of a production-ready container image for running RASP forecasts.
Contrary to most other available setups, a current WRF version is built from scratch.

## Build

The building process is somewhat complicated as we want to keep the final image size as small as possible.
Therefore, the build happens in 3 separate stages that result in intermediate images.
Everything is managed with `docker-compose`, because it lets you configure certain variables in a `.env` file.
Copy or rename the provided `.env.template` and adapt the documented variables to your needs.

### Build base image

```shell
$ docker-compose build base
```

This image will be used in the next steps.
It is based on Fedora Linux and adds common utilities and libraries.

### Build WRF

```shell
$ docker-compose build wrf_build
$ docker-compose build wrf_prod
```

The version of WRF and WPS you have specified in `.env` are fetched from GitHub and compiled from source.
This can take a long time, so be patient and do not worry about the verbose output!

WRF will be compiled with GNU compilers in smpar (i.e. OpenMP) mode (compilation option 33) and with basic nesting support (nesting option 1).

The registry of WRF as well as some compile options are patched, this should be fairly robust but might break in future versions of WRF and WPS.
We use the bare minimum of DrJack's patches to change WRF's registry, so that certain variables which are needed for the RASP plot routines appear in `wrfout` files.
Note however, that DrJack's cloud calculation patches are not applied and thus, `wrf=CFRAC[L|M|H]` are not available (or wrong)!
Use `cfrac[l|m|h]` instead, since those are implemented in the current version of NCL.

##### A note about compile optimizations and CPU architectures
For best performance and to lower computing costs, WRF should be compiled such that it may use all the fancy new features of modern CPUs - this so called instruction set can be specified in `.env` before the build.
For example, if the cloud computing provider you use for RASP has the latest AMD Zen3 CPUs, set `WRF_MARCH_PROD=znver3` (look up the GNU compile option `-march` for a list of supported architectures).

However, `geogrid.exe` must be run in the next build step to set up the region.
This is not possible if the machine you use for this build does not support the instruction set you have chosen above.
No, you cannot build WPS without building WRF first.
No, you cannot set a different architecture for the WPS build.
Hence, there is unfortunately no other possibility but to build WRF a second time with `WRF_MARCH_BUILD=native` and to use `geogrid.exe` from this build.

### Build RASP

**You will need geographical data in `rasp/geog.tar.gz` before you run this step!**
Go to [UCAR's page](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html) and download the appropriate bundle.
See below if you want to use high-resolution SRTM data.

```shell
$ docker-compose build rasp
```

This sets up the directory structure for RASP runs with all necessary binaries and run tables from the WRF image as well as the RASP plotting environment.
Copying the geographical data into the container and unzipping it will take a long time, so please be patient again.
The region you have specified in `.env` is automatically initialized by running `geogrid.exe`.

Finally, in a second build stage, only the necessary artifacts are copied over from the first stage so that the final image remains at an optimal size.

#### Configure RASP output

By default, RASP is configured in this repo to output only GeoTIFFs which can be used with my [RASP viewer](https://github.com/sfalmo/rasp-viewer).
If you want to get the plots as normal images, look for `do_plots = False` in `rasp/GM/plot_funcs.ncl` and set this value to `True`.
You can also disable the GeoTIFF generation in `rasp/bin/runRasp.sh` (remove the call to `rasp2geotiff.py`).

#### Adapt to your own region

You can easily adapt the setup to your own region by providing a region folder similar to `TIR` (which is the region I use) and setting the name of this folder in `.env`.
Remember to also change some region specific aspects of the NCL scripts located in `rasp/GM`.

You need the following data in your region folder:
 - `namelist.wps` for WPS which is used to set up the domain once and pre-process meteorological data before every run
 - `namelist.input` for WRF with all run-specific settings considering numerics, physics options,...
 - A symlink named `Vtable` to the variable table filename you want to use for your GRIB files. For example, if you force your WRF run with GFS data, do `ln -s Vtable.GFS Vtable`. The actual table file does not have to exist on your host machine, it will be provided by WRF for common data sources.

If you use non-stock geog data (e.g. SRTM):
 - Your custom `GEOGRID.TBL`

Note that you can provide any custom tables that WRF/WPS recognizes in your region directory yourself; the respective stock version will then be overwritten.

## Run 

```shell
$ docker-compose run rasp
```

`run -d` makes this a background process.

If you want an interactive shell to your container (e.g. for testing), append `/bin/bash`.
Then, inside the container, execute the entry script `bin/runRasp.sh <region>` to start the RASP run for your `<region>` manually.
To leave the container without stopping the RASP run, type `Ctrl+P Ctrl+Q`.

## View the results

The results of your RASP run should be in `../results/OUT` if everything went well.
Logs are available in `../results/LOG`.

Check out [aufwin.de](https://aufwin.de/forecast), a web app for viewing data generated by RASP.
You can get the source to this RASP viewer from [here](https://github.com/sfalmo/rasp-viewer) and configure site-specific settings to your needs.
