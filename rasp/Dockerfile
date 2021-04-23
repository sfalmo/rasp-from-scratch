FROM eu.gcr.io/aufwinde/wrf:0.1 AS wrf

FROM eu.gcr.io/aufwinde/base:0.1 AS raspbuild
ENV TZ=Europe/Berlin \
  BASEDIR=/root/rasp
COPY --from=wrf /root/rasp/ $BASEDIR

ENV WRF_DIR="${BASEDIR}/WRF_build/WRF" \
  WPS_DIR="${BASEDIR}/WRF_build/WPS"

# Copy WRF executables and scripts to rasp bin folder
RUN mkdir $BASEDIR/bin \
  && for exe in "$WRF_DIR/run/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && cp $WPS_DIR/link_grib.csh $BASEDIR/bin/ \
  && for exe in "$WPS_DIR/util/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && for exe in "$WPS_DIR/ungrib/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && for exe in "$WPS_DIR/geogrid/*.exe"; do cp -L $exe $BASEDIR/bin/; done \
  && for exe in "$WPS_DIR/metgrid/*.exe"; do cp -L $exe $BASEDIR/bin/; done

# Set up region template with run tables from WRF
RUN mkdir $BASEDIR/region.TEMPLATE \
  && mkdir $BASEDIR/region.TEMPLATE/GRIB \
  && mkdir $BASEDIR/region.TEMPLATE/LOG \
  && mkdir $BASEDIR/region.TEMPLATE/OUT \
  && ln -s $BASEDIR/GM $BASEDIR/region.TEMPLATE/GM \
  && cp $WRF_DIR/run/* $BASEDIR/region.TEMPLATE/ && rm $BASEDIR/region.TEMPLATE/*.exe \
  && cp $WPS_DIR/ungrib/Variable_Tables/* $BASEDIR/region.TEMPLATE/ \
  && cp $WPS_DIR/geogrid/GEOGRID* $BASEDIR/region.TEMPLATE/ \
  && cp $WPS_DIR/metgrid/METGRID* $WPS_DIR/metgrid/gribmap.txt $BASEDIR/region.TEMPLATE/

# Add rasp assets (WRF glue scripts, plot scripts, DrJack library, custom stuff)
RUN mkdir -p $BASEDIR/GM/LIB $BASEDIR/lib
COPY bin/ $BASEDIR/bin/
COPY GM/ $BASEDIR/GM/
COPY logo.svg $BASEDIR/
COPY ncl_jack/ncl_jack_fortran.so $BASEDIR/GM/LIB/
COPY ncl_jack/libncl_jack.nocuda.so ncl_jack/libwrf_user.nocuda.so $BASEDIR/lib/

ENV PATH="${BASEDIR}/bin:${PATH}"

# Set up region
RUN mkdir TIR \
  && cp -r region.TEMPLATE/* TIR/
COPY TIR/ $BASEDIR/TIR/

# Copy geog data and run geogrid
COPY geog.tar.gz $BASEDIR
RUN tar xf geog.tar.gz \
  && cd $BASEDIR/TIR/ \
  && geogrid.exe \
  && rm -rf $BASEDIR/geog $BASEDIR/geog.tar.gz \
  && rm -rf $BASEDIR/WRF_build


# --- Actual RASP production image ---
FROM eu.gcr.io/aufwinde/base:0.1
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

VOLUME ["$BASEDIR/TIR/OUT", "$BASEDIR/TIR/LOG"]

# Set environment for interactive container shells
RUN echo export BASEDIR=$BASEDIR >> /etc/bashrc \
  && echo export PATH+=:\$BASEDIR/bin >> /etc/bashrc
