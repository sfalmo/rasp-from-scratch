FROM eu.gcr.io/aufwinde/base:0.1

# required packages
RUN dnf update -y && dnf install -y \
  m4 tcsh git \
  gcc gcc-c++ gcc-gfortran \
  netcdf-devel netcdf-fortran-devel \
  libpng-devel jasper-devel \
  && dnf clean all

RUN mkdir WRF_build && cd WRF_build \
  && git clone https://github.com/wrf-model/WRF.git \
  && git clone https://github.com/wrf-model/WPS.git

COPY Registry.EM_COMMON.patch configure.wrf.patch $BASEDIR/WRF_build/WRF/
COPY configure.wps.patch $BASEDIR/WRF_build/WPS/

ENV CC=gcc \
  CXX=g++ \
  FC=gfortran \
  F77=gfortran \
  FCFLAGS="-m64" \
  FFLAGS="-m64" \
  NETCDF=/usr \
  NETCDF_classic=1

RUN cd $BASEDIR/WRF_build/WRF \
  && patch Registry/Registry.EM_COMMON Registry.EM_COMMON.patch \
  && printf "33\n1\n" | ./configure \
  && patch configure.wrf configure.wrf.patch \
  && ./compile -j 8 em_real \
  && cd ../WPS \
  && printf "1\n" | ./configure \
  && patch configure.wps configure.wps.patch \
  && ./compile

# This does the following:
#
# --- Install WRF ---
# 1) $ ./configure -> option 33 (smpar GNU)
# 2) Edit configure.wrf:
#    - Add "-lnetcdf -lnetcdff" to LIB_EXTERNAL
#    - Add optimizations
# 3) $ ./compile -j <num_procs> em_real
#
# --- Install WPS ---
# 1) ./configure -> option 1 (serial)
# 2) Edit configure.wps:
#    - Add "-I/usr/lib64/gfortran/modules" to WRF_INCLUDE
#    - Add "-lnetcdff -fopenmp" to WRF_LIB
#    - Add "-fallow-argument-mismatch -fallow-invalid-boz" to FFLAGS and F77FLAGS
# 3) ./compile


