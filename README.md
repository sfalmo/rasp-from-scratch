# RASP from scratch

This repo provides Dockerfiles that help in the creation of a production-ready container image for running RASP forecasts.
Contrary to most other available setups, a current WRF version is built from scratch.

## Build

The building process is somewhat complicated as we want to keep the final image size as small as possible.
Therefore, the build happens in 3 separate stages that result in intermediate images.
Everything is managed with `docker compose`, because it lets you configure certain variables in a `.env` file.
Copy or rename the provided `.env.template` and adapt the documented variables to your needs.

### Build base image

```shell
$ docker compose build base
```

This image will be used in the next steps.
It is based on Fedora Linux and adds common utilities and libraries.

### Build WRF and WPS

```shell
$ docker compose build wrf_build
$ docker compose build wrf_prod
```

The version of WRF and WPS you have specified in `.env` are fetched from GitHub and compiled from source.
This can take a long time, so be patient and do not worry about the verbose output!

WRF will be compiled with GNU compilers in smpar (i.e. OpenMP) mode (compilation option 33) and with basic nesting support (nesting option 1).

#### DrJack's patches

The registry of WRF is patched to output some variables that are needed for computing RASP parameters; this should be fairly robust but might break in future versions of WRF.
Note that DrJack's cloud calculation patches are not applied and thus, `wrf=CFRAC[L|M|H]` are not available (or wrong).
Use `cfrac[l|m|h]` instead, since those are implemented in the latest version of NCL.

#### Compilation fixes

There configuration files of WRF and WPS are patched (`patch_configure_wps.sh`, `patch_configure_wrf.sh`) in order to make the compilation of WRF and WPS succeed.
The patches might need to be adapted in future versions of WRF/WPS or when using different compilers.

#### Optimizations

Some default optimization flags for building WRF are overridden in `patch_configure_wrf.sh`; see `OPTFLAGS` for the currently used settings.
You may need to change or omit these rather aggressive optimizations if `wrf.exe` fails.

If a segmentation fault occurs, you might need to increase the value of the environment variable `OMP_STACKSIZE` in `rasp.site.runenvironment` within your region folder (see below).

If in doubt, try using the default optimizations of WRF (usually `-O2`).

#### CPU architectures

For best performance and to lower computing costs, WRF should be compiled such that it may use all the fancy new features of modern CPUs.
The instruction set can be specified in `.env` before the build and will be applied to the `OPTFLAGS` before compiling WRF.
For example, if your cloud computing provider or your own on-premise server has the latest AMD EPYC Turin (Zen5) CPUs, set `WRF_MARCH_PROD=znver5` (look up the GNU compile option `-march` for a list of supported architectures).

But there's a catch.
The WPS program `geogrid.exe` must be run in the next build step to set up the region.
This is not possible if the machine you use for building the next Docker image does not support the instruction set you have chosen above.
No, you cannot build WPS without building WRF first.
No, you cannot set a different architecture for the WPS build.
Hence, there is unfortunately no other possibility but to build WRF a second time with `WRF_MARCH_BUILD=native` and to use `geogrid.exe` from this build.

### Build RASP

**You will need geographical data in `rasp/geog.tar.gz` before you run this step!**
Go to [UCAR's page](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html), download and unpack all required files, place them in a directory `geog`, and build the archive with `tar czf geog.tar.gz geog`.
See below if you want to use high-resolution topograpy or land use data (optional).

```shell
$ docker compose build rasp
```

This sets up the directory structure for RASP runs with all necessary binaries and run tables from the WRF image as well as the RASP plotting environment.
Copying and decompressing the geographical data will take a long time, so please be patient again.
The region you have specified in `.env` is automatically initialized by running `geogrid.exe` and is set as the default region via an environment variable.

Finally, in a second build stage, only the necessary artifacts are copied over from the first stage so that the final image remains at an optimal size.

#### Configure RASP output

By default in this repo, RASP is configured to output only GeoTIFFs which can be used with my [RASP viewer](https://github.com/sfalmo/rasp-viewer).
If you want to get the plots as normal images, look for `do_plots = False` in `rasp/GM/plot_funcs.ncl` and set this value to `True`.
You can also disable the GeoTIFF generation in `rasp/bin/runRasp.sh` (remove the call to `rasp2geotiff.py`).

### Adapt to your own region

You can easily adapt the setup to your own region by providing a region folder similar to `TIR` (which is the region I use) and setting the name of this folder in `.env`.
Remember to go through all `rasp.*` files within this directory to adapt region-specific settings to your needs.

You need the following data in your region folder:
 - `namelist.wps` for WPS which is used to set up the domain and pre-process meteorological data before every run.
 - `namelist.input` for WRF with all run-specific settings considering dynamics, physics, etc.
 - A symlink named `Vtable` to the variable table filename that is applicable to your GRIB files. For example, if you force your WRF run with GFS data (see the corresponding setting `$GRIBFILE_MODEL` in `rasp.run.parameters.*`), make a symlink via `ln -s Vtable.GFS Vtable`. The actual table file does not have to exist on your host machine if you want to use one of the stock Vtables of WPS, see [https://github.com/wrf-model/WPS/tree/master/ungrib/Variable_Tables](https://github.com/wrf-model/WPS/tree/master/ungrib/Variable_Tables) for the available options.

If you use bespoke geography data (e.g. SRTM topography or custom land use data), provide your custom `GEOGRID.TBL`; see `TIR/GEOGRID.TBL` for an example where SRTM topography and CORINE land use data is incorporated.
Otherwise, the default `GEOGRID.TBL` from WPS will be used.

Generally, you can provide any custom tables that WRF/WPS recognizes in your region directory yourself; the respective stock version will then be overwritten.

## Run 

```shell
$ docker compose run -d rasp
```

If you want an interactive shell to your container (e.g. for testing), run
```shell
$ docker compose run rasp /bin/bash
```

Then, inside the container, execute the entry script `runRasp.sh` to run RASP for the default region as specified by the environment variable `REGION`.
To leave the container without stopping the RASP run, type <kbd>Ctrl</kbd>+<kbd>P</kbd> <kbd>Ctrl</kbd>+<kbd>Q</kbd>.

## View results

Upon successful completion, results should be in `../results/OUT`.
Logs are available in `../results/LOG`.

Check out the forecast on [aufwin.de](https://aufwin.de/forecast), a web app for viewing data generated by RASP based on this repo.
The source to this RASP viewer can be found [here](https://github.com/sfalmo/rasp-viewer); site-specific settings may need to be configured according to your setup.
