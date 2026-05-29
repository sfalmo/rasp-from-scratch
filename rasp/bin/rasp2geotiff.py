import re
import glob
import numpy as np
import json
from osgeo import gdal, osr
import sys
from datetime import datetime

def getBoundaryFromMetgrid(metgridfile):
    netcdf = 'NETCDF:"'+metgridfile+'":'
    ds_lon_c = gdal.Open(netcdf+'XLONG_C')
    ds_lat_c = gdal.Open(netcdf+'XLAT_C')

    lon_c = ds_lon_c.GetRasterBand(1).ReadAsArray()
    lat_c = ds_lat_c.GetRasterBand(1).ReadAsArray()

    ds_lon_c = None
    ds_lat_c = None

    return [
        *[(float(lat), float(lon)) for lat, lon in zip(lat_c[0,:], lon_c[0,:])],
        *[(float(lat), float(lon)) for lat, lon in zip(lat_c[:,-1], lon_c[:,-1])],
        *[(float(lat), float(lon)) for lat, lon in zip(lat_c[-1,::-1], lon_c[-1,::-1])],
        *[(float(lat), float(lon)) for lat, lon in zip(lat_c[::-1,0], lon_c[::-1,0])]
    ]

def getWRFSpatialReference(trueLat1, trueLat2, refLng, centerLat):
    wrf_srs = osr.SpatialReference()
    wrf_srs.ImportFromProj4("+proj=lcc +lat_1={trueLat1} +lat_2={trueLat2} +lat_0={centerLat} +lon_0={refLng} +a=6370000 +b=6370000 +units=m +datum=WGS84 +no_defs=True".format(trueLat1=trueLat1, trueLat2=trueLat2, centerLat=centerLat, refLng=refLng))
    return wrf_srs

def getGeoTransform(wrf_srs, upper_left, dx, dy):
    srs_out = osr.SpatialReference()
    srs_out.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    srs_out.SetGeogCS('', wrf_srs.GetAttrValue('datum'), '', wrf_srs.GetSemiMajor(), wrf_srs.GetInvFlattening())
    transform = osr.CoordinateTransformation(srs_out, wrf_srs)
    ul = transform.TransformPoint(upper_left[1], upper_left[0])
    return (ul[0], dx, 0, -ul[1], 0, dy)

def writeGeoTIFF(filename, data, wrf_srs, gt):
    driver = gdal.GetDriverByName("MEM")
    griddata = driver.Create("temp", data.shape[1], data.shape[0], 1, gdal.GDT_Int32)
    griddata.SetGeoTransform(gt)
    griddata.SetProjection(wrf_srs.ExportToWkt())
    griddata.GetRasterBand(1).WriteArray(data)
    griddata.GetRasterBand(1).SetNoDataValue(-999999)
    warp = gdal.Warp(filename, griddata, dstSRS='EPSG:3857', format='GTiff', resampleAlg='cubicspline', xRes=abs(gt[1]), yRes=abs(gt[-1]), creationOptions=['INTERLEAVE=BAND', 'COMPRESS=DEFLATE', 'PREDICTOR=2'])
    warp = None


if len(sys.argv) != 2:
    print("Script must be called with path to wrfout and rasp data files")
    exit(1)

path = sys.argv[1]
print(path)

boundary = getBoundaryFromMetgrid(glob.glob(path+'/met_em.d02.*')[0])
print("boundary[0]:", boundary[0])

parameters = set()
hours = set()
press_levels = set()

datafiles = glob.glob(path+"/OUT/*.data")
for datafile in datafiles:
    print("Converting "+datafile+" to GeoTIFF")
    filename = datafile.split("/")[-1]

    re_search = re.search(r'(.*?)\.curr\.(.*?)lst\.d.*\.data', filename)
    if re_search:
        parameter = re_search.group(1)
        parameters.add(parameter)
        hours.add(re_search.group(2))
        press_search = re.search(r'press(\d+)', parameter)
        if press_search:
            press_levels.add(int(press_search.group(1)))

    re_search = re.search(r'pfd_tot\.data', filename)
    if re_search:
        parameters.add('pfd_tot')

    with open(datafile, 'r') as d:
        d.readline()
        d.readline()
        gridinfo_raw = d.readline()
        paraminfo_raw = d.readline()
        data_raw = d.readlines()

    proj_raw = re.search(r'Proj= (.*?)$', gridinfo_raw).group(1)
    projName, dx, dy, trueLat1, trueLat2, refLng, centerLat, centerLng = proj_raw.split()
    dx, dy, trueLat1, trueLat2, refLng, centerLat, centerLng = [float(i) for i in [dx, dy, trueLat1, trueLat2, refLng, centerLat, centerLng]]

    try:
        data = np.loadtxt(data_raw, dtype=int)
    except:
        data = np.around(np.loadtxt(data_raw)).astype(int)

    wrf_srs = getWRFSpatialReference(trueLat1, trueLat2, refLng, centerLat)
    gt = getGeoTransform(wrf_srs, boundary[0], dx, dy)
    writeGeoTIFF(datafile+'.tiff', data, wrf_srs, gt)

with open(path+"/OUT/parameters.json", "w") as f:
    json.dump({'timestamp': datetime.now().isoformat(), 'parameters': list(parameters), 'hours': sorted(list(hours)), 'press_levels': sorted(list(press_levels), reverse=True), 'boundary': boundary, 'center': [centerLat, centerLng], 'dx': dx, 'dy': dy}, f)
