ARG WRF_VERSION
ARG WPS_VERSION
ARG WRF_MARCH
ARG BASE_IMAGE

FROM ${BASE_IMAGE}
ARG WRF_VERSION
ARG WPS_VERSION
ARG WRF_MARCH

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
  NETCDF=/usr \
  NETCDF_classic=1

RUN mkdir build && cd build \
  && git clone --branch ${WRF_VERSION} --depth 1 https://github.com/wrf-model/WRF.git \
  && git clone --branch ${WPS_VERSION} --depth 1 https://github.com/wrf-model/WPS.git

COPY Registry.EM_COMMON.patch $BASEDIR/build/WRF/
RUN cd $BASEDIR/build/WRF \
  && patch Registry/Registry.EM_COMMON Registry.EM_COMMON.patch \
  && printf "33\n1\n" | ./configure \
  && echo "Patching config with -march=${WRF_MARCH}" \
  && sed -i "s/^\(CFLAGS_LOCAL\s*=\s*\).*/\1-w -O3 -c -ftree-vectorize -funroll-loops -ffast-math -flto -march=${WRF_MARCH}/" configure.wrf \
  && sed -i "s/^\(LDFLAGS_LOCAL\s*=\s*\).*/\1-O3 -ftree-vectorize -funroll-loops -ffast-math -flto -march=${WRF_MARCH}/" configure.wrf \
  && sed -i "s/^\(FCOPTIM\s*=\s*\).*/\1-O3 -ftree-vectorize -funroll-loops -ffast-math -flto -march=${WRF_MARCH}/" configure.wrf \
  && sed -i 's!-L$(WRF_SRC_ROOT_DIR)/external/io_netcdf -lwrfio_nf -L/usr/lib!-L$(WRF_SRC_ROOT_DIR)/external/io_netcdf -lwrfio_nf -L/usr/lib -lnetcdf -lnetcdff!' configure.wrf \
  && ./compile -j 8 em_real

# Must be built after WRF
RUN cd $BASEDIR/build/WPS \
  && printf "1\n" | ./configure \
  && sed -i 's!-I$(NETCDF)/include!-I$(NETCDF)/include -I/usr/lib64/gfortran/modules!' configure.wps \
  && sed -i 's!-L$(NETCDF)/lib  -lnetcdf!-L$(NETCDF)/lib  -lnetcdf -lnetcdff -fopenmp!' configure.wps \
  && ./compile

# This first installs WRF in smpar GNU mode (option 33) and WPS in serial GNU mode (option 1).
# Some parameters in the compile configurations must be changed for the compilation to succeed.
