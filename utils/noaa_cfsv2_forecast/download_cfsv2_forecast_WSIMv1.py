#!python
# cfsv2_get_grib.py
# 30 Jun 10.  RML.
# A script to download NCEP CFS forecast data
# Does not download retrospective forecasts or observed data

# This should be scheduled to run with cron (Linux) or with launchd (OSX)

# Modified (September 2022: boright) to run with python 3 on Windows. Hard-coded base-dir.   


import sys, os #, platform
# from datetime import date
import pycurl

def grep(string,list):
    """ Returns the strings in 'list' that contain 'string' """
    import re
    expr = re.compile(string)
    return filter(expr.search,list)

# def mountCaptured():
#     # Specify the base directory to which files should be saved.

#     captured_ip = '192.168.2.211'  # IP address for 'Captured'
#     user='wsimop'
#     pw='3bingo4'
#     # mountpoint = '/Volumes/WSIM_Source'
#     # mountpoint = '/mnt/Captured/WSIM_Source'
#     mountpoint = '/mnt/Captured/WSIM_Source'
#     mount_cmd = 'mount_smbfs //{0}:{1}@{2}/WSIM_Source {3}'.format(user, pw,     captured_ip, mountpoint)
#     return mountpoint, mount_cmd

def getLinks(url, pattern):
    import re
    # import urllib3
    import ssl
    import urllib.request
    from bs4 import BeautifulSoup
    #print 'url = {}'.format(url)
    #print 'pattern = {}'.format(pattern)
    #page = urllib.request.urlopen(url)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    page = urllib.request.urlopen(url, context=ctx)
    soup = BeautifulSoup(page, 'html.parser')

    # Find the anchor tags where href = True (represents a link)
    links = soup.find_all(name = 'a', href = True, text = re.compile(pattern))
    links = [l.contents[0] for l in links]

    return sorted(links)

def getFile(url, filename):
    ## check for corrupted (very small) files here.
    if os.path.exists(filename): 
         file_stats = os.stat(filename)
         if file_stats.st_size < 5000: #file size less than 5 Kb
             print("incomplete file found... {}  \n\tdeleting it".format(os.path.basename(filename)))
             os.remove(filename)
    
    if not os.path.exists(filename):    
        print('\n Downloading {}\n to {}\n'.format(url, filename))
        fp = open(filename, "wb")
        curl = pycurl.Curl()
        curl.setopt(pycurl.URL, str(url))
        curl.setopt(pycurl.FOLLOWLOCATION, 1)
        curl.setopt(pycurl.MAXREDIRS, 5)
        curl.setopt(pycurl.CONNECTTIMEOUT, 30)
        curl.setopt(pycurl.TIMEOUT, 300)
        curl.setopt(pycurl.NOSIGNAL, 1)
        curl.setopt(pycurl.WRITEDATA, fp)
        try:
            curl.perform()
            curl.close()
            fp.close()
        except:
            import traceback
            traceback.print_exc(file=sys.stderr)
            sys.stderr.flush()
            os.remove(filename)
        sys.stdout.write(".")
        sys.stdout.flush()
        print('Success!')
    return

def getAllGrib(localdir, urlbase, ic_dates):
    import os
    # import string
    for i in range(0, len(ic_dates)):
        cfs_dir = str(ic_dates[i])
        #cfs_dir = cfs_dir [1:-1] # jb results in dirname 'fs.[date]... missing the initial 'c'
        cfs_dir = cfs_dir [:-1] # jb changed to get the dirname correct
        print('Working on %s\n' % cfs_dir)
        icDir =os.path.join(localdir, cfs_dir)
        # print 'localdir: %s' % icDir
        if not os.path.isdir(icDir):
            os.makedirs(icDir)
        daily_url = urlbase + '/' + cfs_dir
        # print 'daily_url: {}'.format(daily_url)
        #ic_folders = getLinks(url = daily_url, pattern = 'cfs*')
        ic_folders = getLinks(url = daily_url, pattern = '[0-9]{2}/')
        for ic in ic_folders:
            #hourlyUrl = daily_url + "/" + ic[1:]
            hourlyUrl = daily_url + "/" + ic #jb fixed folder
            gribpages = getLinks(url = hourlyUrl, pattern='monthly_grib_01')
            for gr in gribpages:
                #gribUrl = hourlyUrl + gr[1:-1]
                gribUrl = hourlyUrl + gr[:-1]
                #print 'gribUrl: {}'.format(gribUrl)
                flxfList = getLinks(url = gribUrl, pattern = 'flx')
                flxfList = grep('avrg.grib.grb2$', flxfList)
                for flxf in flxfList:
                    #fileUrl = gribUrl + '/' + flxf[1:]
                    fileUrl = gribUrl + '/' + flxf
                    #print 'fileUrl = '+fileUrl
                    #fileName = os.path.join(icDir , flxf[1:])
                    fileName = os.path.join(icDir , flxf)
                    #print 'fileName = '+fileName
                    getFile(fileUrl, fileName)
    return

def changeDate(dateFile, newdate):
    f = open(dateFile, 'r+b')
    fileContents = f.readlines()
    newContents = fileContents
    newGribDate = "latestGRIB = '" + newdate + "' # Set by cfsv2.get.grib.py\n"
    newContents[3] = str.encode(newGribDate)
    f.seek(0)
    f.writelines(newContents)
    f.close()

    return


##########################################################################
# Do the work.
##########################################################################

if __name__ == '__main__':

    # Call getgrib function here.
    # Define directories

    # Get basedir
    basedir = r"\\192.168.100.210\\wsim\\WSIM_source_V1.2"

    cfsdir = os.path.join(basedir, 'NCEP.CFSv2')

    #rdirbase= '/pub/data/nccf/com/cfs/para/cfs'
    #urlbase = "http://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs"
    urlbase = "http://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod"

    s = 'Running 07a_cfsv2.get.grib.py.\nDownloading from {urlbase}.\nSaving to {cfsdir}.\n'.format(urlbase=urlbase, cfsdir=cfsdir)  

    print(s)

    # Create the directory to download the new forecasts
    ic_dates = getLinks(url = urlbase, pattern = 'cfs\.')
    last_date =  str(ic_dates[-1][4:12]) 
    gribdir = os.path.join(cfsdir, 'raw_forecast')
    if not os.path.exists(gribdir):
        os.makedirs(gribdir)

    # Finally, get the new forecasts
    getAllGrib(localdir = gribdir, urlbase = urlbase, ic_dates = ic_dates)

    dateFile = os.path.join(cfsdir, 'forecast', 'latest_forecast.txt')

    changeDate(dateFile, last_date)

    print('\nSuccessful completion')

# EOF
