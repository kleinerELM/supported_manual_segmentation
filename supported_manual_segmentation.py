# -*- coding: utf-8 -*-
#import csv
import os, sys, getopt
os.environ["OPENCV_IO_MAX_IMAGE_PIXELS"] = str(10000000000)
#import tifffile as tiff
import cv2
import math
import numpy as np
import pandas as pd
from PIL import Image
Image.MAX_IMAGE_PIXELS = 10000000000 # prevent decompressionbomb warning for typical images
import tkinter as tk
from tkinter import filedialog
import time
import subprocess
from subprocess import check_output
import multiprocessing
import matplotlib.pyplot as plt
import napari

def programInfo():
    print("#########################################################")
    print("# segment alite for grenoble paper                      #")
    print("#                                                       #")
    print("# © 2021 Florian Kleiner                                #")
    print("#   Bauhaus-Universität Weimar                          #")
    print("#   Finger-Institut für Baustoffkunde                   #")
    print("#                                                       #")
    print("#########################################################")
    print()

# import other libaries by kleinerELM
home_dir = os.path.dirname(os.path.realpath(__file__))

ts_path = os.path.dirname( home_dir ) + os.sep + 'tiff_scaling' + os.sep
ts_file = 'extract_tiff_scaling'
if ( os.path.isdir( ts_path ) and os.path.isfile( ts_path + ts_file + '.py' ) or os.path.isfile( home_dir + ts_file + '.py' ) ):
    if ( os.path.isdir( ts_path ) ): sys.path.insert( 1, ts_path )
    import extract_tiff_scaling as es
else:
    programInfo()
    print( 'missing ' + ts_path + ts_file + '.py!' )
    print( 'download from https://github.com/kleinerELM/tiff_scaling' )
    sys.exit()

rsb_file = 'remove_SEM_scalebar'
rsb_path = os.path.dirname( home_dir ) + os.sep + 'remove_SEM_scalebar' + os.sep
if ( os.path.isdir( rsb_path ) and os.path.isfile( rsb_path +rsb_file + '.py' ) or os.path.isfile( home_dir + rsb_file + '.py' ) ):
    if ( os.path.isdir( rsb_path ) ): sys.path.insert( 1, rsb_path )
    import remove_SEM_scalebar as rsb
else:
    programInfo()
    print( 'missing ' + rsb_path + rsb_file + '.py!' )
    print( 'download from https://github.com/kleinerELM/remove_SEM_scalebar' )
    sys.exit()

import basic_functions_libary as basic

mcld_file = 'size_distribution_class'
mcld_path = os.path.dirname( home_dir ) + os.sep + 'Measure_Cord_Length_Distribution' + os.sep
if ( os.path.isdir( mcld_path ) and os.path.isfile( mcld_path + mcld_file + '.py' ) or os.path.isfile( home_dir + mcld_file + '.py' ) ):
    if ( os.path.isdir( mcld_path ) ): sys.path.insert( 1, mcld_path )
    import size_distribution_class as mcld
else:
    programInfo()
    print( 'missing ' + rsb_path + rsb_file + '.py!' )
    print( 'download from https://github.com/kleinerELM/Measure_Cord_Length_Distribution' )
    sys.exit()

# Initial function to load the settings
def getBaseSettings():
    settings = {
        "showDebuggingOutput"  : False,
        "force_pixel_size"     : None,
        "home_dir"             : os.path.dirname(os.path.realpath(__file__)),
        "workingDirectory"     : "",
        "outputDirectory"      : "processed",
        "correction_factor"    : 1.0, #  or 4/math.pi #proposed by Krumbein 1935 and JOHNSON 1994 to correct radius and diameter due to sections of spheres
        "lower_diameter_limit" : 124,
        "upper_diameter_limit" : 10000,
        "do_multiprocessing"   : False,
        "summarize"            : False,
        "show_result"          : False
    }
    return settings

#### process given command line arguments
def processArguments():
    settings = getBaseSettings()
    argv = sys.argv[1:]
    usage = sys.argv[0] + " [-h] [-o] [-c] [-b] [-m] [-s] [-r] [-l:] [-d]"
    try:
        opts, args = getopt.getopt(argv,"hobmsrcl:d",[])
    except getopt.GetoptError:
        print( usage )
    for opt, arg in opts:
        if opt == '-h':
            print( 'usage: ' + usage )
            print( '-h,                  : show this help' )
            print( '-o,                  : setting output directory name [{}]'.format(settings["outputDirectory"]) )
            print( '-l,                  : limit pixel scaling [{}]'.format(settings["outputDirectory"]) )
            print( '-c                   : correct the diameter values with the factor 4/Pi [Krumbein 1935]' )
            print( '-b                   : assume the images are already binary (black background, white objects)' )
            print( '-m                   : enable multithreaded processing' )
            print( '-s                   : summarize the data of all images' )
            print( '-r                   : show resulting image' )
            print( '-d                   : show debug output' )
            print( '' )
            sys.exit()
        elif opt in ("-o"):
            settings["outputDirectory"] = arg
            print( 'changed output directory to {}'.format(settings["outputDirectory"]) )
        elif opt in ("-c"):
            settings["correction_factor"] = 4/math.pi
            print( 'changed the correction_factor from 1.0 to {:.4f}'.format(settings["correction_factor"]) )
        elif opt in ("-m"):
            settings["do_multiprocessing"] = True
            print( 'multithreaded processing enabled' )
        elif opt in ("-s"):
            settings["summarize"] = True
            print( 'summarize the data of all images' )
        elif opt in ("-r"):
            settings["show_result"] = False
            print( 'show resulting image' )
        elif opt in ("-l"):
            settings["force_pixel_size"] = int( arg )
            print( 'changed the lower pixel size limit to {} nm. All images will be scaled down accordingly.'.format(settings["force_pixel_size"]) )
        elif opt in ("-d"):
            print( 'show debugging output' )
            settings["showDebuggingOutput"] = True
    print( '' )
    return settings

def getTargetFolder(settings):
    fps  = '' if settings["force_pixel_size"] is None else '_{}nm'.format(settings["force_pixel_size"])
    fps += '_nc' if settings["correction_factor"] == 1 else '_c'
    targetDirectory = settings["workingDirectory"] + os.sep + settings["outputDirectory"] + fps + os.sep
    #if settings["createFolderPerImage"]:
    #    targetDirectory += file_name + os.sep
    ## create output directory if it does not exist
    if not os.path.exists( targetDirectory ):
        os.makedirs( targetDirectory )
    return targetDirectory

def process_result_row( settings, contour, scale = 1, area_limit = 4, feret_limit = 0.2, extend_limit = 0.2 ):
    result_row = False
    area = cv2.contourArea(contour)*(scale**2)
    diameter_raw = basic.getPoreDiameter(area) # uncorrected diameter - raw data diameter
    diameter = basic.getPoreDiameter(area)*settings["correction_factor"]


    if area > area_limit :
        # filter malformed particles (segmented curtaining)
        rect = cv2.minAreaRect(contour)
        r_w, r_h = rect[1]
        feret = r_w / r_h if r_w < r_h else  r_h / r_w
        extend = area / (r_w * r_h*(scale**2))

        if feret > feret_limit and extend > extend_limit:
            rect = cv2.minAreaRect(contour)
            r_w, r_h = rect[1]
            if settings["correction_factor"] != 1: area = basic.getPoreArea(diameter)# * math.pi*((diameter/2)**2)
            result_row = [
                diameter,
                area,
                basic.getPoreSurface(diameter=diameter),
                basic.getPoreVolume(diameter=diameter)]

    return result_row

def generate_single_diagram( settings, result_list, filename ):
    # process PSD and diagrams
    df = pd.DataFrame(result_list , columns = ['diameter', 'area', 'surface', 'volume'])
    df.to_csv(filename + '.csv')

    dia_bins  = np.logspace(np.log10(1),np.log10(df['diameter'].max()),100)
    dia       = df['diameter'].to_list()

    area_bins = np.logspace(np.log10(1),np.log10(df['area'].max()),100)
    area      = df['area'].to_list()

    vol_bins  = np.logspace(np.log10(1),np.log10(df['volume'].max()),100)
    volumes   = df['volume'].to_list()

    lower_diameter_limit = settings["lower_diameter_limit"]*settings["correction_factor"]
    upper_diameter_limit = settings["upper_diameter_limit"]*settings["correction_factor"]
    """
    fig, ((ax1), (ax2), (ax3)) = plt.subplots(3, 1)
    ax1.hist(dia, bins=dia_bins)
    ax1.set_xscale('log')
    ax1.set_title('diameter in nm')
    #ax1.set_xlabel('diameter in nm')
    ax1.set_ylabel('particle count')
    ax1.set_xlim(lower_diameter_limit, upper_diameter_limit)

    ax2.hist(area, bins=area_bins)
    ax2.set_xscale('log')
    ax2.set_title('area in nm²')
    #ax2.set_xlabel('area in nm²')
    ax2.set_ylabel('particle count')
    ax2.set_xlim(basic.getPoreArea(lower_diameter_limit), basic.getPoreArea(upper_diameter_limit))

    ax3.hist(volumes, bins=vol_bins)
    ax3.set_xscale('log')
    ax3.set_title('volume in nm³')
    #ax3.set_xlabel('volume in nm³')
    ax3.set_ylabel('particle count')
    ax3.set_xlim(basic.getPoreVolume(lower_diameter_limit), basic.getPoreVolume(upper_diameter_limit))

    fig.tight_layout()
    plt.savefig(filename + '.png')
    plt.close()
    """

    return df

def get_denoised_img(img, smoothing_factor = 0):
    f = [
        {'h':10,
        'templateWindowSize':7,
        'searchWindowSize':21},
        {'h':17,
        'templateWindowSize':7,
        'searchWindowSize':21},
    ]
    img = cv2.fastNlMeansDenoising( img,
                            h                    = f[smoothing_factor]['h'],
                            templateWindowSize = f[smoothing_factor]['templateWindowSize'],
                            searchWindowSize   = f[smoothing_factor]['searchWindowSize']
                            )

    return img

# since saving the scaling of a Tiff image does nor really wor reliable, this functions saves the image using PIL
def save_with_scaling(path, img, scaling):
    im_pil = Image.fromarray(img)
    im_pil.save( path, tiffinfo = es.setImageJScaling( scaling ) )

def process_particles(file_name, file_extension, scaling, settings):
    if not settings["do_multiprocessing"]: print('  load image')

    paths = {
        # source image
        'src': settings["workingDirectory"] + os.sep + file_name + file_extension,
        # image withour info bar height
        'cut': settings['targetDirectory'] + os.sep + file_name + '_cut' + file_extension,
        # denoised image
        'nlm': settings['targetDirectory'] + os.sep + file_name + '_nlm' + file_extension,
        # mask with ignored areas in white
        'ign': settings['targetDirectory'] + os.sep + file_name + '_ignored_area' + file_extension,
        # selected pore mask
        'por': settings['targetDirectory'] + os.sep + file_name + '_pores' + file_extension,
        # image with colored, overlayed masks (red: ignored, green: pores)
        'col': settings['targetDirectory'] + os.sep + file_name + '_ignored_area_m' + file_extension
    }

    # loading version without Infobar
    if not os.path.isfile(paths['cut']):
        img = cv2.imread(paths['src'], cv2.IMREAD_GRAYSCALE)

        infoBarHeight = rsb.getInfoBarHeightFromMetaData( settings["workingDirectory"], file_name + file_extension, verbose=True )
        img = rsb.removeScaleBarCV( img, infoBarHeight=infoBarHeight)

        save_with_scaling(paths['cut'], img, scaling)
    else:
        img = cv2.imread(paths['cut'], cv2.IMREAD_GRAYSCALE)

    # loading denoised image
    if not os.path.isfile(paths['nlm']):
        if not settings["do_multiprocessing"]:  print("  Non-local Means Denoising")
        img = get_denoised_img(img, smoothing_factor = 0)

    else:
        img = cv2.imread(paths['nlm'], cv2.IMREAD_GRAYSCALE)

    h, w = img.shape[:2]
    image_area = h * w * ((scaling['x']/1000)**2)

    # Phansalkar thresholding
    # img1 = basic.get_phansalkar_binary(img, window_size=33, k=0.6, p=0.6, q=10.0)
    img1 = basic.get_phansalkar_binary(img, window_size=39, k=0.30, p=0.5, q=10.0)


    pore_area = 0
    pore_areas, _ = cv2.findContours(np.invert(img1).astype(np.uint8) * 255, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

    for i in range(len(pore_areas)):
        pore_area += cv2.contourArea(pore_areas[i])*((scaling['x']/1000)**2)

    if pore_area > 0.5*image_area or len(pore_areas)>3000:
        print('  pore area is very large. wrong segmentation suspected. Changing denoising parameters')

        # reloading denoised image
        if not settings["do_multiprocessing"]:  print("  Non-local Means Denoising")
        img = get_denoised_img(img, smoothing_factor = 1)
        img1 = basic.get_phansalkar_binary(img, window_size=39, k=0.30, p=0.5, q=10.0)

    # black backround with white objects and convert to 0 to 255
    mask = np.invert(img1).astype(np.uint8) * 255

    # basic morphological filters
    mask = basic.morph(mask, 'dilate', morph_size=1)
    #mask = basic.fill_holes( mask )
    mask = basic.morph(mask, 'erode', morph_size=1)
    mask2 = basic.morph(mask, 'dilate', morph_size=1)

    remove_area_size = 0
    if not os.path.isfile(paths['ign']):
        if not settings["do_multiprocessing"]:  print("  asking for areas to ignore")

        with napari.gui_qt():
            viewer = napari.view_image(img, name='select ' + file_name)
            viewer.scale_bar.visible = True

        has_removed_area = ( len(viewer.layers) > 1 and not settings["do_multiprocessing"] )
        if has_removed_area:
            shapes = viewer.layers[1].data
            ignored_areas = []
            for j, shape in enumerate(shapes):
                cv_shape = []
                for i, point in enumerate(shape):

                    if point[0] < 1:
                        shape[i][0] = 0

                    if point[0] > h:
                        shape[i][0] = h-1

                    if point[1] < 1:
                        shape[i][1] = 0

                    if point[1] > w:
                        shape[i][1] = w-1

                    shape[i][0] = int(shape[i][0])
                    shape[i][1] = int(shape[i][1])

                    cv_shape.append( [shape[i][1], shape[i][0]] )

                shapes[j] = shape
                ignored_areas.append(np.array(cv_shape, dtype=np.int32))

            # save ignore mask
            removed_area_mask = cv2.drawContours(np.zeros([h, w], np.uint8), ignored_areas, contourIdx=-1, color=(255), thickness=-1)
            save_with_scaling(paths['ign'], removed_area_mask, scaling)


    else:
        removed_area_mask = cv2.imread(paths['ign'], cv2.IMREAD_GRAYSCALE)
        ignored_areas, _ = cv2.findContours(removed_area_mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        has_removed_area = True

    if has_removed_area:
        # reprocess mask2
        mask2 = cv2.drawContours(mask2, ignored_areas, contourIdx=-1, color=(0), thickness=-1)

        # get size of ignored area(s)
        for i in range(len(ignored_areas)):
            remove_area_size += cv2.contourArea(ignored_areas[i])*(scaling['x']**2)/(1000**2)
        if settings['showDebuggingOutput']: print('  ignored area {:.2f} µm²'.format(remove_area_size))

        img = basic.overlay_mask(img, removed_area_mask, color=(255,0,0))

    if settings["show_result"]:
        with napari.gui_qt():
            viewer = napari.view_image(img, name='result ' + file_name)
            viewer.scale_bar.visible = True

    # remove grains below a certain size
    area_limit  = 4
    min_size_nm = area_limit * (scaling['x']**2)
    if not settings["do_multiprocessing"]: print( '  removing objects below an area of {:.2f} nm²'.format(min_size_nm) )

    feret_limit = 0.2 # remove thin objects
    extend_limit = 0.3 # remove objects with very little area/rectarea (multiple thin and connected)

    contours, _ = cv2.findContours(mask2, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    selected_contours = []
    result_list = []

    for i in range(len(contours)):#start_pos, end_pos):
        result_row = process_result_row( settings, contours[i], scale = scaling['x'], area_limit = area_limit, feret_limit = feret_limit, extend_limit = extend_limit)
        if result_row != False:
            result_list.append( result_row )
            selected_contours.append(contours[i])

    if not settings["do_multiprocessing"]: print('  removed {} objects from segmented {} objects'.format( len(contours)-len(result_list), len(contours) ))

    selected_mask = np.zeros(img.shape[:2], dtype="uint8")
    if len(result_list) > 0:
        # process PSD and diagrams
        filename = settings["targetDirectory"] + file_name + '_psd'
        df = generate_single_diagram(settings, result_list, filename)

        cv2.drawContours(selected_mask, selected_contours, -1, 255, -1)

        summary_list = calculate_summary(file_name, df, h, w, scaling, settings, remove_area_size)
    else:
        summary_list = []
        df = pd.DataFrame(columns = ['diameter', 'area', 'surface', 'volume'])
        print('no valid grain object found in {} !'.format(file_name))

    # colored_mask works with RGB -> therefore conversion is needed
    img = basic.overlay_mask(img, selected_mask, color=(0,255,0))
    # write final phansalkar mask
    save_with_scaling(paths['por'], selected_mask, scaling)
    save_with_scaling(paths['col'], cv2.cvtColor(img, cv2.COLOR_RGB2BGR), scaling)

    # SD = mcld.size_distribution()
    # cld_h = SD.process_directional_CLD( img, 'horizontal', verbose=True)
    # cld_v = SD.process_directional_CLD( img, 'vertical', verbose=True)

    return summary_list, df

def calculate_summary(file_name, df, h, w, scaling, settings, remove_area_size):
    surf_sum      = df['surface'].sum()
    volume_sum    = df['volume'].sum()
    diameter_mean = df['diameter'].mean()
    diameter_std  = df['diameter'].std() if len(df['diameter']) > 1 else 0

    # px³ to cm³
    cubic_cm = (1/(10**7) )**3

    # px² to cm²
    square_cm = ( 1/(10**7) )**2

    # px² to m²
    square_m = ( 1/(10**9) )**2

    #density_alite = 3.15 #[g/cm³]

    surface_m = surf_sum * square_m
    volume_cm = volume_sum * cubic_cm
    image_area = h * w * ((scaling['x']/1000)**2)
    #spec_surf_unit = surface_m / ( density_alite * volume_cm )
    if not settings["summarize"]:
        print('-'*40 )
        print(' {} results:'.format( file_name ) )
        print('  image_area            = {:.2f} µm x {:.2f} µm = {:.2f} µm²'.format( (w*scaling['x']/1000), (h*scaling['y']/1000), ( image_area ) ) )
        print('  analyzed image_area   = {:.2f} µm² ({:.2f} %)'.format(  (image_area - remove_area_size), (100/image_area*(image_area-remove_area_size)) ) )
        print('  pixel size            = ({:.2f} nm)²'.format( scaling['x'] ) )
        print('  analyzed particles    = {}'.format(len(df)) )
        if diameter_mean > 900:
            print('  mean diameter         = {:.2f} ± {:.2f} µm'.format( diameter_mean/1000, diameter_std/1000 ) )
        else:
            print('  mean diameter         = {:.2f} ± {:.2f} nm'.format( diameter_mean, diameter_std ) )
        print('  surface               = {:.3e} m²'.format( surface_m ) )
        print('  volume                = {:.3e} cm³'.format( volume_cm ) )
        print('-'*40 )
        print()
    df['pixel size'] = scaling['x']
    return [ file_name, int(w*scaling['x']), int(h*scaling['y']),  int(h * w * ((scaling['x'])**2)), len(df), diameter_mean, diameter_std,  surface_m, volume_cm, remove_area_size, scaling['x'] ]

def store_result(result):
    # global result_df_list
    # global summary_list
    global result_df

    summary_list_item, df = result
    if len(summary_list_item) > 0:
        if settings["summarize"]:
            result_df = result_df.append(df, ignore_index = True)

        summary_list.append( summary_list_item )
        result_df_list[summary_list_item[0]] = df

### actual program start
if __name__ == '__main__':
    #remove root windows
    root = tk.Tk()
    root.withdraw()

    coreCount = multiprocessing.cpu_count()
    processCount = (coreCount - 1) if coreCount > 1 else 1

    settings = processArguments()
    if ( settings["showDebuggingOutput"] ) : print( "I am living in '{}'".format(settings["home_dir"] ) )
    settings["workingDirectory"] = filedialog.askdirectory(title='Please select the working directory')
    if ( settings["showDebuggingOutput"] ) : print( "Selected working directory: " + settings["workingDirectory"] )
    allowed_file_extensions = [ '.tif' ]


    if os.path.isdir( settings["workingDirectory"] ) :
        settings["targetDirectory"] = getTargetFolder(settings)
        if not os.path.isdir( settings["targetDirectory"] ): os.mkdir(settings["targetDirectory"])

        ## count valid files and get image scaling
        image_list = []
        for file in os.listdir(settings["workingDirectory"]):
            file_name, file_extension = os.path.splitext( file )
            if ( file_extension.lower() in allowed_file_extensions ):
                print('-'*40)
                print(file_name + file_extension)
                # process units
                scaling = es.autodetectScaling( file_name + file_extension, settings["workingDirectory"], verbose=False )
                print(scaling)
                if scaling['unit'] != 'nm':
                    #print(scaling)
                    print('{}: UNIT {} IS WRONG!!! Expected nm. processing will fail or give wrong results.'.format(file_name, scaling['unit']))

                # append to image list
                image_list.append((file_name, file_extension, scaling))
        print( "{} images found!".format(len(image_list)) )

        print()
        print( 'Processing image' )

        # create result dictionary containing dataframes of pore data
        position = 0
        result_columns = ['diameter', 'area', 'surface', 'volume', 'pixel size']
        result_df_list = {}
        result_df = pd.DataFrame(columns=result_columns)
        summary_list = []

        ## processing files
        if settings["do_multiprocessing"]:
            pool = multiprocessing.Pool(processCount)
            for file_name, file_extension, scaling in image_list:
                position += 1
                print( " Analysing {} ({}/{}) :".format(file_name + file_extension, position, len(image_list)) )

                pool.apply_async(process_particles, args=(file_name, file_extension, scaling, settings), callback = store_result )

            pool.close()
            pool.join()
        else:
            for file_name, file_extension, scaling in image_list:
                position += 1
                print( " Analysing {} ({}/{}) :".format(file_name + file_extension, position, len(image_list)) )

                store_result( process_particles(file_name, file_extension, scaling, settings) )

        df_summary = pd.DataFrame(summary_list , columns = ['filename', 'width [nm]', 'height [nm]', 'area [nm²]', 'analyzed particles', 'mean diameter [nm]', 'mean diameter std [nm]', 'surface [m²]', 'volume [cm³]', 'ignored area [µm²]', 'pixel size [nm/px]'] )
        df_summary.to_csv(settings["targetDirectory"] + 'summary.csv')
        print('saving to {}'.format(settings["targetDirectory"] + 'all_pores.csv'))
        result_df.to_csv(settings["targetDirectory"] + 'all_pores.csv')

    print( "Script DONE!" )