import re
import glob
import numpy as np
import gdal, osr
import sys

def getLatLngBoundsFromWRF(wrfoutfile):
    netcdf = 'NETCDF:"'+wrfoutfile+'":'
    ds_lon_u = gdal.Open(netcdf+'XLONG_U')
    ds_lat_u = gdal.Open(netcdf+'XLAT_U')
    ds_lon_v = gdal.Open(netcdf+'XLONG_V')
    ds_lat_v = gdal.Open(netcdf+'XLAT_V')

    lon_u = ds_lon_u.GetRasterBand(1).ReadAsArray()
    lat_u = ds_lat_u.GetRasterBand(1).ReadAsArray()
    lon_v = ds_lon_v.GetRasterBand(1).ReadAsArray()
    lat_v = ds_lat_v.GetRasterBand(1).ReadAsArray()

    ds_lon_u = None
    ds_lat_u = None
    ds_lon_v = None
    ds_lat_v = None

    lower_left_u = (lon_u[0,0], lat_u[0,0])
    lower_right_u = (lon_u[0,-1], lat_u[0,-1])
    lower_left_v = (lon_v[0,0], lat_v[0,0])
    upper_left_v = (lon_v[-1,0], lat_v[-1,0])

    return (lower_left_u, lower_right_u, lower_left_v, upper_left_v)

def getWRFSpatialReference(trueLat1, trueLat2, refLng, centerLat):
    wrf_srs = osr.SpatialReference()
    wrf_srs.ImportFromProj4("+proj=lcc +lat_1={trueLat1} +lat_2={trueLat2} +lon_0={refLng} +lat_0={centerLat} +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs".format(trueLat1=trueLat1, trueLat2=trueLat2, refLng=refLng, centerLat=centerLat))
    return wrf_srs

def getGeoTransform(wrf_srs, bounds, dataDim):
    srs_out = osr.SpatialReference()
    if hasattr(osr, 'OAMS_TRADITIONAL_GIS_ORDER'):
        srs_out.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    srs_out.SetGeogCS('', wrf_srs.GetAttrValue('datum'), '', wrf_srs.GetSemiMajor(), wrf_srs.GetInvFlattening())
    transform = osr.CoordinateTransformation(srs_out, wrf_srs)

    ll_u, lr_u, ll_v, ul_v = [transform.TransformPoint(float(i[0]), float(i[1])) for i in bounds]
    dx = (lr_u[0] - ll_u[0]) / dataDim[0]
    dy = (ul_v[1] - ll_v[1]) / dataDim[1]
    gt = (ll_u[0], dx, 0, -ll_v[1], 0, -dy)
    return gt

def writeGeoTIFF(filename, data, wrf_srs, gt):
    driver = gdal.GetDriverByName("MEM")
    griddata = driver.Create("temp", data.shape[0], data.shape[1], 1, gdal.GDT_Float32)
    griddata.SetGeoTransform(gt)
    griddata.SetProjection(wrf_srs.ExportToWkt())
    griddata.GetRasterBand(1).WriteArray(data)
    griddata.GetRasterBand(1).SetNoDataValue(-999999)
    warp = gdal.Warp(filename, griddata, dstSRS='EPSG:4326', format='GTiff', resampleAlg='cubicspline')
    warp = None


if len(sys.argv) != 2:
    print("Script must be called with path to wrfout and rasp data files")
    exit(1)

path = sys.argv[1]
bounds = getLatLngBoundsFromWRF(glob.glob(path+'/wrfout_d02_*')[0])
datafiles = glob.glob(path+"/OUT/*.data")
print(path)
print(datafiles)
for datafile in datafiles:
    print("Converting "+datafile+" to geoTIFF")
    with open(datafile, 'r') as d:
        d.readline()
        d.readline()
        gridinfo_raw = d.readline()
        paraminfo_raw = d.readline()
        data_raw = d.readlines()

    proj_raw = re.search(r'Proj= (.*?)$', gridinfo_raw).group(1)
    projName, dX, dY, trueLat1, trueLat2, refLng, centerLat, centerLng = proj_raw.split()
    dX, dY, trueLat1, trueLat2, refLng, centerLat, centerLng = [float(i) for i in [dX, dY, trueLat1, trueLat2, refLng, centerLat, centerLng]]

    mult = re.search(r'Mult= (.*?) ', paraminfo_raw).group(1)
    data = np.loadtxt(data_raw)
    if mult != '1': # Better not introduce floating point errors
        mult = float(mult)
        data /= mult

    wrf_srs = getWRFSpatialReference(trueLat1, trueLat2, refLng, centerLat)
    gt = getGeoTransform(wrf_srs, bounds, data.shape)
    writeGeoTIFF(datafile+'.tiff', data, wrf_srs, gt)


