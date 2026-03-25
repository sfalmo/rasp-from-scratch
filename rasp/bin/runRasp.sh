#!/bin/bash

# check parameters
if [ $# -eq 0 ]; then
    if [ -z "${REGION}" ]; then
        echo "ERROR: $0 called without argument and REGION not set in environment"
        echo "Provide region as first argument"
	exit 1
    fi
elif [ $# -eq 1 ]; then
    if [ -n "${REGION}" ]; then
        echo "WARNING: REGION=${REGION} set in environment will be overridden by first argument $1"
	REGION="$1"
    fi
else
    echo "ERROR: $0 called with too many arguments"
    exit 1
fi

if [ -z "${START_DAY}" ]; then
    START_DAY=0;
fi

regionDir="/root/rasp/${REGION}"
outDir="${regionDir}/OUT"
logDir="${regionDir}/LOG"

. ${regionDir}/rasp.site.runenvironment

# cleanup of images that may be mounted
echo "Removing previous results so current run is not contaminated"
rm -rf ${outDir}/*
rm -rf ${logDir}/*
rm -rf ${regionDir}/wrfout_d0*

runDate="$(date +%Y-%m-%d)"
runTime="$(date +%H-%M)"

echo "Running runGM on area ${REGION}, startDay = ${START_DAY} and hour offset = ${OFFSET_HOUR}"
runGM ${REGION}

#Generate the meteogram images
echo "Running meteogram on $(date)"
cp /root/rasp/logo.svg ${regionDir}/OUT/logo.svg
ncl /root/rasp/GM/meteogram.ncl DOMAIN=\"${REGION}\" SITEDATA=\"/root/rasp/GM/sitedata.ncl\" &> ${logDir}/meteogram.out

# Generate title JSONs from data files
perl /root/rasp/bin/title2json.pl /root/rasp/${REGION}/OUT &> ${logDir}/title2json.out

# Generate geotiffs from data files
python3 /root/rasp/bin/rasp2geotiff.py /root/rasp/${REGION} &> ${logDir}/rasp2geotiff.out

# Move or copy some additional files
mv ${regionDir}/wrf.out ${logDir}
mv ${regionDir}/metgrid.log ${logDir}
mv ${regionDir}/ungrib.log ${logDir}
cp ${regionDir}/namelist.wps ${logDir}
cp ${regionDir}/namelist.input ${logDir}

echo "Started running rasp at ${runDate}_${runTime}, ended at $(date +%Y-%m-%d_%H-%M)"

if [[ "${WEBSERVER_SEND}" == "1" ]]
then
    remoteLogDir="${WEBSERVER_RESULTSDIR}/LOG/${REGION}/${runDate}/${START_DAY}"
    remoteOutDir="${WEBSERVER_RESULTSDIR}/OUT/${REGION}/${runDate}/${START_DAY}"
    # Get ssh key from environment
    echo "${SSH_KEY}" > aufwinde_key
    chmod 0600 aufwinde_key
    # Create directories on webserver
    ssh -i aufwinde_key -o StrictHostKeychecking=no "${WEBSERVER_USER}@${WEBSERVER_HOST}" "mkdir -p ${remoteOutDir} ${remoteLogDir}"
    if [[ "$(ls -A ${outDir})" ]]
    then
        # If there is output, sync it. Otherwise, back off and be happy with the data that is already on the webserver
        echo "Sending results to ${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteOutDir}"
        rsync -e "ssh -i aufwinde_key -o StrictHostKeychecking=no" -rlt --delete-after "${outDir}/" "${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteOutDir}"
        if [[ "${SEND_WRFOUT}" == "1" ]]
        then
            echo "Sending wrfout files to ${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteOutDir}"
            echo "Stripping wrfout files variables"
            for wrfout in "${regionDir}"/wrfout_d02_*
            do
                ncks -v XLAT,XLONG,HGT,P,PH,PB,PHB,T,U,V,W,CLDFRA,QCLOUD,QVAPOR,EDMF_W -O "$wrfout" "$wrfout"
            done
            # wrfout files from the start of the simulation (early morning hours) are excluded, which is currently hardcoded. If you are in another timezone, adapt or remove the --exclude flag
            rsync -e "ssh -i aufwinde_key -o StrictHostKeychecking=no" -rlt --exclude='*0[3-5]:00:00' "${regionDir}"/wrfout_d02_* "${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteOutDir}"
        fi
    fi
    # Always sync contents of log directory. Do this afterwards because the copying of the results might take a while and the website is confused if the logs exist but the corresponding results do not
    echo "Sending logs to ${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteLogDir}"
    rsync -e "ssh -i aufwinde_key -o StrictHostKeychecking=no" -rlt --delete-after "${logDir}/" "${WEBSERVER_USER}@${WEBSERVER_HOST}:${remoteLogDir}"
fi

if [[ "${REQUEST_DELETE}" == "1" ]]
then
    fqdn=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google")
    hostname=$(printf ${fqdn} | cut -d. -f1)
    zone=$(printf ${fqdn} | cut -d. -f2)
    project=$(printf ${fqdn} | cut -d. -f4)
    echo "Self-destruction of $hostname in zone $zone in project $project"
    token=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google" | perl -MJSON -0lnE '$json = decode_json $_; say $json->{access_token};')
    curl -XDELETE -H "Authorization: Bearer ${token}" https://www.googleapis.com/compute/v1/projects/$project/zones/$zone/instances/$hostname
fi
