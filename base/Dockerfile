FROM fedora:35

ENV TZ=Europe/Berlin \
  BASEDIR=/root/rasp
RUN mkdir $BASEDIR
WORKDIR $BASEDIR

RUN dnf update -y && dnf install -y \
  which time findutils less vim patch \
  libpng jasper \
  netcdf netcdf-fortran \
  && dnf clean all
