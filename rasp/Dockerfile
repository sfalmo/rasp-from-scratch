ARG BASE_IMAGE
ARG WRF_IMAGE
ARG WRF_VERSION
ARG REGION

FROM ${WRF_IMAGE}:${WRF_VERSION} AS wrf

FROM ${BASE_IMAGE} AS raspbuild
ARG REGION
ENV TZ=Europe/Berlin \
  BASEDIR=/root/rasp
COPY --from=wrf /root/rasp/ $BASEDIR

ENV WRF_DIR="${BASEDIR}/build/WRF" \
  WPS_DIR="${BASEDIR}/build/WPS"

# Copy WRF executables and scripts to rasp bin folder and set up region folder with WRF tables
RUN mkdir -p $BASEDIR/bin $BASEDIR/${REGION}/GRIB $BASEDIR/${REGION}/LOG $BASEDIR/${REGION}/OUT \
  && ln -s $BASEDIR/GM $BASEDIR/${REGION}/GM \
  && for exe in "$WRF_DIR/run/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && cp $WPS_DIR/link_grib.csh $BASEDIR/bin/ \
  && for exe in "$WPS_DIR/util/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && for exe in "$WPS_DIR/ungrib/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && for exe in "$WPS_DIR/geogrid/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && for exe in "$WPS_DIR/metgrid/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && cp $WRF_DIR/run/* $BASEDIR/${REGION}/ && rm $BASEDIR/${REGION}/*.exe \
  && cp $WPS_DIR/ungrib/Variable_Tables/* $BASEDIR/${REGION}/ \
  && cp $WPS_DIR/geogrid/GEOGRID* $BASEDIR/${REGION}/ \
  && cp $WPS_DIR/metgrid/METGRID* $WPS_DIR/metgrid/gribmap.txt $BASEDIR/${REGION}/ \
  && rm -rf $BASEDIR/build

ENV PATH="${BASEDIR}/bin:${PATH}"

# Copy only the stuff we need for geogrid
COPY geog.tar.gz $BASEDIR
COPY ${REGION}/namelist.wps ${REGION}/GEOGRID.TBL $BASEDIR/${REGION}/
# Extract geog data and run geogrid. Do this all in one take to keep the image size small
RUN tar xf geog.tar.gz \
  && cd "$BASEDIR/${REGION}/" \
  && cp namelist.wps namelist.wps.template \
  && geogrid.exe \
  && rm -rf $BASEDIR/geog $BASEDIR/geog.tar.gz

# Add rasp assets (WRF glue scripts, plot scripts, DrJack library, custom stuff) and the rest of the region folder
# Do this afterwards so we do not trigger the copying and extraction of geog data each time we change scripts or namelist.input settings
RUN mkdir -p $BASEDIR/GM/LIB $BASEDIR/lib
COPY bin/ $BASEDIR/bin/
COPY GM/ $BASEDIR/GM/
COPY logo.svg $BASEDIR/
COPY ncl_jack/ncl_jack_fortran.so $BASEDIR/GM/LIB/
COPY ncl_jack/libncl_jack.nocuda.so ncl_jack/libwrf_user.nocuda.so $BASEDIR/lib/
COPY ${REGION}/ $BASEDIR/${REGION}/
RUN cp ${REGION}/namelist.input ${REGION}/namelist.input.template \
  && mv $BASEDIR/${REGION}/rasp.region_data.ncl $BASEDIR/${REGION}/sitedata.ncl $BASEDIR/GM/

# --- Actual RASP production image ---
FROM ${BASE_IMAGE}
ARG REGION
ENV REGION ${REGION}
ARG WRF_VERSION
ENV WRF_VERSION ${WRF_VERSION}
COPY --from=raspbuild /root/rasp/ $BASEDIR
ENV PATH="${BASEDIR}/bin:${PATH}"

# Required packages for RASP
RUN dnf update -y && dnf install -y \
  libomp \
  nco ncl \
  psmisc procps-ng pigz \
  sendmail procmail mailx \
  ImageMagick \
  perl-CPAN perl-JSON \
  python3 gdal-python3 \
  openssh-clients rsync \
  && dnf clean all

# Configure CPAN and install Proc::Background
RUN (echo y;echo o conf prerequisites_policy follow;echo o conf commit) | cpan \
  && cpan install Proc/Background.pm

# NCL fights with ncl_jack_fortran.so if this is not done
COPY ncl_jack/WRFUserARW.ncl.patch $BASEDIR/GM/
RUN patch /usr/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl $BASEDIR/GM/WRFUserARW.ncl.patch

VOLUME ["$BASEDIR/${REGION}/OUT", "$BASEDIR/${REGION}/LOG"]

# Set environment for interactive container shells
RUN echo export BASEDIR=$BASEDIR >> /etc/bashrc \
  && echo export PATH+=:\$BASEDIR/bin >> /etc/bashrc

CMD runRasp.sh ${REGION}
