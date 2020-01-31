# supported_manual_segmentation
ImageJ macro to manually segment CSH phases of BSE or SE images and automatically segment the pores within the selection. The images have to be prepared to have the scalebar removed and the scale has to be saved in the metadata of the file for ImageJ!

On the fist start the script shows a setting menu to adjust the script:
 * Batch processing (directory). -  You can coose to process a directory full of images at once.
 * Use non local mean denoising (else smooth). -  Choose the denoising algorithm
 * Threshold type: - One of three thresholding methods to segment the pores.
 * Normal threshold method: - Ff "normal threshold" is selected, the frim imageJ provided method can be selected here.
 * Automatically try to create outer Mask. - This will activate an automatic outer selection (only suitable in a few cases).
 * Manually remove inner areas during processing? - If active, the script will ask you to select inner areas which should be ignored.
 * Ask for cleanup options. - always aks if on of the cleanup options below will be applied to an image.
 *   Else: Auto crop bottom (4px)? - Removes 4px high lines from the bottom of the image.
 *   Else: Do 'Erode/Dilate'? - modifies the pore selection using standard binary operations
 *         or: Do 'Despecle'? - modifies the pore selection using standard binary operations
 *   Else: Do 'Close-'?	- modifies the pore selection using standard binary operations
 *   Else: Do 'Fill Holes'? - modifies the pore selection using standard binary operations
 * Exclude border particles from analysis? - Particles touching the border of an image will be ignored

The script first denoises the image using the selected algorithm.
Then you have to select the CSH area or the area of interest. Holes can be selected in the second step (which will be repeated until you have selected every hole which should not be analysed).
The script will then create a csv file in the folder "manual_segmentation" containing the size of the manual segmented area.
Afterwards the script thresholds the original image using the selected threshold method to segment the pores. The pore binary and the manual mask images will then be combined in a way, that only the pores within the selected area remain.
The pores are then cleaned using standard binary operations like erode, dilate, close, despecle an/or "Fill Holes".
Another csv file containing all pore sizes is finally created and saved in the folder "full_segmentation".

The intermediate mask images will also be saved in the mentioned subfolders.

run from command line:
```
ImageJ-win64.exe -macro "C:\path\to\supported_manual_segmentation.ijm" "D:\path\to\file.tif|thresholdType|thresholdStdMethod"
```

thresholdType: 0 = Auto Local Threshold (Phansalkar); 1 = Robust Automatic Threshold Selection; 2 = standard
thresholdStdMethod: Standard methods provided by ImageJ (same order, from 0 to 16)

To analyze the data and to process some characteristic parameters and diagrams, run the generate_diagram.py python scipt and select the full_segmentation folder.


expected CSV Format:
poreNr,Area,Circularity,Feret,FeretX,FeretY,FeretAngle,MinFeret,AR,Round,Solidity