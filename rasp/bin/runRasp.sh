#!/bin/bash

# check parameters
usage="$0 <region> - execute runGM on <region>, create meteograms and copy results to right location"
if [ $# -ne 1 ] ; then
    echo "ERROR: require one region to run, no/too many arguments provided"
    echo $usage;
    exit 1;
fi
region=${1}
if [ -z "${START_DAY}" ] ; then
    START_DAY=0;
fi

regionDir="/root/rasp/${region}"
outDir="${regionDir}/OUT"
logDir="${regionDir}/LOG"

. ${regionDir}/rasp.site.runenvironment

# cleanup of images that may be mounted
echo "Removing previous results so current run is not contaminated"
rm -rf ${regionDir}/OUT/*
rm -rf ${regionDir}/OUT/*
rm -rf ${regionDir}/wrfout_d0*

startDate=$(date +%Y%m%d);
startTime=$(date +%H%M);
startDateTime=$(date);

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

runSubdir="${regionDir}"
if [[ "$START_DAY" != "0" ]]
then
  runSubdir="${regionDir}+${START_DAY}"
fi
targetDir="${outDir}/${runSubdir}"
mkdir -p ${targetDir}
rm -rf ${targetDir}/*

# Move results
mv ${outDir}/*.data ${targetDir}
mv ${outDir}/*.json ${targetDir}
mv ${outDir}/*.tiff ${targetDir}
mv ${outDir}/*.png ${targetDir}
chmod 644 ${targetDir}/*

# Move log files for further analysis
mv ${regionDir}/wrf.out ${logDir}
mv ${regionDir}/metgrid.log ${logDir}
mv ${regionDir}/ungrib.log ${logDir}

echo "Started running rasp at ${startDate} ${startTime}, ended at $(date)"

if [[ "${WEBSERVER_SEND}" == "1" ]]
then
  # Always sync contents of log directory
  rsync -e "ssh -i aufwinde_key -o StrictHostKeychecking=no" -rlt --delete-after "${logDir}/" "${WEBSERVER_USER}@${WEBSERVER_HOST}:${WEBSERVER_RESULTSDIR}/LOG/"
  if [[ "$(ls -A ${targetDir})" ]]
  then
    # If there is output, sync it. Otherwise, back off and be happy with the data that is already on the webserver
    rsync -e "ssh -i aufwinde_key -o StrictHostKeychecking=no" -rlt --delete-after ${targetDir} "${WEBSERVER_USER}@${WEBSERVER_HOST}:${WEBSERVER_RESULTSDIR}/OUT/"
  fi
fi

if [[ "${REQUEST_DELETE}" == "1" ]]
then
  token=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google" | perl -MJSON -0lnE '$json = decode_json $_; say $json->{access_token};')
  curl -XDELETE -H "Authorization: Bearer ${token}" https://www.googleapis.com/compute/v1/projects/aufwinde/zones/europe-west3-c/instances/$HOSTNAME
fi
