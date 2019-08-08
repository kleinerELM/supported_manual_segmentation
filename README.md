# supported_manual_segmentation
ImageJ macro to manually segment CSH phases of BSE or SE images and automatically segment the pores within the selection automatically. The images have to be prepared to have the scalebar removed and the scale has to be saved in the metadata of the file for ImageJ!

The script first smoothes the image using "Non-local Means Denoising".
Then you have to select the CSH area or the area of interest. Holes can be selected in the second step (which will be repeated until you have selected every hole which should not be analysed).
The script will then create a csv file in the folder "manual_segmentation" containing the size of the manual segmented area.
Afterwards the script thresholds the original image using "Auto Local Threshold" (method "Phansalkar") to segment the pores. The pore binary and the manual mask images will then be contain in a way that only the pores within the selected area remain.
The pores are then cleaned using erode, dilate and close.
Another csv file containing all pore sizes is finally created and saved in the folder "full_segmentation".

The intermediate mask images will also be saved in the mentioned subfolders.

run from command line:
```
ImageJ-win64.exe -macro "C:\path\to\supported_manual_segmentation.ijm" "D:\path\to\file.tif|thresholdType|thresholdStdMethod"
```

thresholdType: 0 = Auto Local Threshold (Phansalkar); 1 = Robust Automatic Threshold Selection; 2 = standard
thresholdStdMethod: Standard methods provided by ImageJ (same order, from 0 to 16)