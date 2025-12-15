ARG FEDORA_VERSION

FROM fedora:${FEDORA_VERSION}

ENV TZ=Europe/Berlin \
  BASEDIR=/root/rasp
RUN mkdir $BASEDIR
WORKDIR $BASEDIR

RUN dnf update -y && dnf install -y \
  which time findutils less vim patch diffutils python3 \
  libpng jasper \
  netcdf netcdf-fortran \
  && dnf clean all
