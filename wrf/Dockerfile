ARG WRF_VERSION
ARG WPS_VERSION
ARG BASE_IMAGE

FROM ${BASE_IMAGE}
ARG WRF_VERSION
ARG WPS_VERSION

# required packages
RUN dnf update -y && dnf install -y \
  m4 tcsh git \
  gcc gcc-c++ gcc-gfortran \
  netcdf-devel netcdf-fortran-devel \
  libpng-devel jasper-devel \
  && dnf clean all

ENV CC=gcc \
  CXX=g++ \
  FC=gfortran \
  F77=gfortran \
  FCFLAGS="-m64" \
  FFLAGS="-m64" \
  NETCDF=/usr \
  NETCDF_classic=1

RUN mkdir build && cd build \
  && git clone --branch ${WRF_VERSION} --depth 1 https://github.com/wrf-model/WRF.git \
  && git clone --branch ${WPS_VERSION} --depth 1 https://github.com/wrf-model/WPS.git

COPY Registry.EM_COMMON.patch configure.wrf.patch $BASEDIR/build/WRF/
RUN cd $BASEDIR/build/WRF \
  && patch Registry/Registry.EM_COMMON Registry.EM_COMMON.patch \
  && printf "33\n1\n" | ./configure \
  && patch configure.wrf configure.wrf.patch \
  && ./compile -j 8 em_real

# Must be build after WRF
COPY configure.wps.patch $BASEDIR/build/WPS/
RUN cd $BASEDIR/build/WPS \
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
# 3) ./compile
