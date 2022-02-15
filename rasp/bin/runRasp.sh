#!/bin/bash

# check parameters
usage="$0 <region> - execute runGM on <region>, create meteograms and copy results to right location"
if [ $# -ne 1 ] ; then
    echo "ERROR: require one region to run, no/too many arguments provided"
    echo $usage;
    exit 1;
fi
region=$1
if [ -z "${START_DAY}" ] ; then
    START_DAY=0;
fi

regionDir="/root/rasp/${region}"
outDir="${regionDir}/OUT"
logDir="${regionDir}/LOG"

. ${regionDir}/rasp.site.runenvironment

# cleanup of images that may be mounted
echo "Removing previous results so current run is not contaminated"
rm -rf ${outDir}/*
rm -rf ${logDir}/*
rm -rf ${regionDir}/wrfout_d0*

startDate="$(date +%Y%m%d)";
startTime="$(date +%H%M)";

echo "Running runGM on area ${region}, startDay = ${START_DAY} and hour offset = ${OFFSET_HOUR}"
runGM ${region}

#Generate the meteogram images
echo "Running meteogram on $(date)"
cp /root/rasp/logo.svg ${regionDir}/OUT/logo.svg
ncl /root/rasp/GM/meteogram.ncl DOMAIN=\"${region}\" SITEDATA=\"/root/rasp/GM/sitedata.ncl\" &> ${logDir}/meteogram.out

# Generate title JSONs from data files
perl /root/rasp/bin/title2json.pl /root/rasp/${region}/OUT &> ${logDir}/title2json.out

# Generate geotiffs from data files
python3 /root/rasp/bin/rasp2geotiff.py /root/rasp/${region} &> ${logDir}/rasp2geotiff.out

# Move some additional log files
mv ${regionDir}/wrf.out ${logDir}
mv ${regionDir}/metgrid.log ${logDir}
mv ${regionDir}/ungrib.log ${logDir}

echo "Started running rasp at ${startDate} ${startTime}, ended at $(date)"

if [[ "${WEBSERVER_SEND}" == "1" ]]
then
  datestamp=$(date +%Y-%m-%d -d "+${START_DAY} days")
  remoteLogDir="${WEBSERVER_RESULTSDIR}/LOG/${REGION}_${datestamp}"
  remoteOutDir="${WEBSERVER_RESULTSDIR}/OUT/${REGION}_${datestamp}"
  echo "Sending logs to ${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteLogDir} and results to ${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteOutDir}"
  # Get ssh key from environment
  echo "${SSH_KEY}" > aufwinde_key
  chmod 0600 aufwinde_key
  # Create directory on webserver
  ssh -i aufwinde_key -o StrictHostKeychecking=no "${WEBSERVER_USER}@${WEBSERVER_HOST}" "mkdir -p ${remoteLogDir}"
  ssh -i aufwinde_key -o StrictHostKeychecking=no "${WEBSERVER_USER}@${WEBSERVER_HOST}" "mkdir -p ${remoteOutDir}"
  # Always sync contents of log directory
  rsync -e "ssh -i aufwinde_key -o StrictHostKeychecking=no" -rlt --delete-after "${logDir}/" "${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteLogDir}"
  if [[ "$(ls -A ${outDir})" ]]
  then
    # If there is output, sync it. Otherwise, back off and be happy with the data that is already on the webserver
    rsync -e "ssh -i aufwinde_key -o StrictHostKeychecking=no" -rlt --delete-after --exclude='*.png' "${outDir}/" "${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteOutDir}"
  fi
fi

if [[ "${REQUEST_DELETE}" == "1" ]]
then
  echo "Self-destruction of $HOSTNAME"
  token=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google" | perl -MJSON -0lnE '$json = decode_json $_; say $json->{access_token};')
  curl -XDELETE -H "Authorization: Bearer ${token}" https://www.googleapis.com/compute/v1/projects/aufwinde/zones/europe-west3-c/instances/$HOSTNAME
fi
