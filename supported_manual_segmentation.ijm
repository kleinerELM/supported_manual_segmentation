// Macro for ImageJ 1.52d for Windows
// written by Florian Kleiner 2019
// run from command line as follows
// ImageJ-win64.exe -macro "C:\path\to\remove_scalebar.ijm" "D:\path\to\data\|outputDirName|infoBarheight|metricScale|pixelScale"

function createInnerMask( filename, selectWindowName ) {
	selectWindow( selectWindowName );
	choice = getBoolean("If there are large voids inside area of interest\nyou can select them now.\nClick [Yes] to proceed or [No] to skip the action. Press [Cancel] to stop the macro.");
	if ( choice ) {
		waitForUser("Create inner Mask", "Select the inner mask. Click [OK] if ready.");
		stype = selectionType();
		if ( stype == 2 ) { // 0=rectangle, 1=oval, 2=polygon, 3=freehand, 4=traced, 5=straight line, 6=segmented line, 7=freehand line, 8=angle, 9=composite, 10=point, -1=no selection. 
			run("Fit Spline");
		}
		if ( stype > 0 ) {
			print( "   - Selection found." );
			run("Create Mask");
			run("Select None"); // remove selection
		} else {
			print( "   - No selection found. Aborting..." );
		}
		choice = createInnerMask( filename, selectWindowName );
	}
	return choice;
}

function redrawComposit( compositeTitle, maskTitle, filename ) {
		selectWindow( compositeTitle );//selectImage(imageId);
		close();
		selectWindow( maskTitle );
		run("Merge Channels...", "c1=" + maskTitle + " c4=" + filename + " create keep");
}

macro "supported_manual_segmentation" {
	// check if an external argument is given or define the options
	arg = getArgument();
	if ( arg == "" ) {
		filePath 		= File.openDialog("Choose a file");
		//define number of slices for uniformity analysis
	} else {
		print("arguments found");
		arg_split = split(getArgument(),"|");
		filePath		= arg_split[0];
	}
	dir = File.getParent(filePath);
	print("Starting process using the following arguments...");
	print("  File: " + filePath);
	print("  Directory: " + dir);
	print("------------");
	
	//directory handling
	outputDir_manual = dir + "/manual_segmentation/";
	outputDir_full = dir + "/full_segmentation/";
	File.makeDirectory(outputDir_manual);
	File.makeDirectory(outputDir_full);
	
	list = getFileList(dir);
	//setBatchMode(true);
	// process only images
	if (!endsWith(filePath,"/") && ( endsWith(filePath,".tif") || endsWith(filePath,".jpg") || endsWith(filePath,".JPG") ) ) {
		open(filePath);
		imageId = getImageID();
		// get image id to be able to close the main image
		if (nImages>=1) {
			//////////////////////
			// name definitions
			//////////////////////
			filename = getTitle();
			print( filename );
			baseName		= substring(filename, 0, lengthOf(filename)-4);
			cutName			= baseName + "-cut.tif";
			poreName		= "PoreBinary";
			maskTitle 		= "Mask";
			compositeTitle	= "Composite";
			
			//////////////////////
			// image constants
			//////////////////////
			width			= getWidth();
			height			= getHeight();
			
			//////////////////////
			// initial processing
			//////////////////////
			print(" - denoising");
			run("Non-local Means Denoising", "sigma=10 smoothing_factor=1 auto");
			run("Enhance Contrast...", "saturated=0.3");

			//////////////////////
			// remove noise and holes from pore mask
			//////////////////////
			cleanup = getBoolean("Do you want to crop the image?\nEg if there is intense noise at the borders.\nPress [Cancel] to stop the macro.");
			if ( cleanup ) {
			print(" - cropping");
				setTool("rectangle");
				waitForUser("Select the area you want to keep.", "Press [OK] when ready..");
				run("Crop");
			}
			
			//////////////////////
			// thresholding and cleanup
			//////////////////////
			print(" - thresholding and cleanup");
			setAutoThreshold("Otsu dark");// Minimum
			run("Create Mask");
			run("Erode");
			run("Dilate");
			run("Dilate");
			run("Erode");
			run("Fill Holes");
			
			rename( maskTitle );
			run("Merge Channels...", "c1=" + maskTitle + " c4=" + filename + " create keep");
			selectWindow( compositeTitle );//selectImage(imageId);

			//////////////////////
			// make selections
			//////////////////////
			setTool("freehand");
			//setBatchMode("show");
			print(" - outer manual selection");
			waitForUser("Select the outer area.", "Add something to outer mask.\nIf the red mask contains everything that should be selected press OK\nor select additional areas and press [OK].");
			stype = selectionType();
			if ( stype == 2 ) { // 0=rectangle, 1=oval, 2=polygon, 3=freehand, 4=traced, 5=straight line, 6=segmented line, 7=freehand line, 8=angle, 9=composite, 10=point, -1=no selection. 
				run("Fit Spline");
			}
			if ( stype > 0 ) {
				print( "   - Selection found." );
				run("Create Mask");
				run("Select None"); // remove selection
				//TODO Combine masks
			} else {
				print( "   - nothing selected, skipping." );
			}
			
			redrawComposit( compositeTitle, maskTitle, filename );

			selectWindow( maskTitle );
			run("Invert"); 
			selectWindow( compositeTitle );//selectImage(imageId);
			
			//rename( "outerMask" )
			print(" - inner manual selection");
			createInnerMask( filename, compositeTitle );
			//run("Select None"); // remove selection
			selectWindow( maskTitle );
			run("Invert"); // reinvert image to get the actual mask
			
			redrawComposit( compositeTitle, maskTitle, filename );
			print(" - saving manual selection...");
			saveAs("Tiff", outputDir_manual + "composit_" + filename );

			selectWindow( maskTitle );
			// try to elminate border effects
			run("Options...", "iterations=4 count=1 black do=Erode");
			//saveAs("Tiff", outputDir_manual + filename );
			//rename( maskTitle );
			run("Set Measurements...", "area area_fraction redirect=None decimal=5");
			run("Measure");
			selectWindow("Results");
			saveAs("Text", outputDir_manual + substring(filename, 0, lengthOf(filename)-4) + "_area.csv");
			selectImage(imageId);

			//////////////////////
			// try to segment pores
			// 3 possible algorythms!
			//////////////////////
			print(" - thresholding");
			thresholdType = 3;
			if ( thresholdType == 1 ) {
				print( "   - Auto Local Threshold (Phansalkar)" );
				run("Auto Local Threshold", "method=Phansalkar radius=10 parameter_1=0 parameter_2=0");
			} else if ( thresholdType == 2 ) {
				print( "   - Robust Automatic Threshold Selection" );
				run("Robust Automatic Threshold Selection", "noise=25 lambda=3 min=354");
				run("Invert");
			} else if ( thresholdType == 3 ) {
				print( "   - Otsu" );
				setAutoThreshold("Otsu");// Minimum	
				run("Create Mask");
			}
			rename( poreName );
			
			//////////////////////
			// remove noise and holes from pore mask
			//////////////////////
			cleanup = getBoolean("Do you want to clean the result using Erode/Dilate?\nPress [Cancel] to stop the macro.");
			if ( cleanup ) {
				print( "   - cleaning pore selection" );
				//selectWindow( maskTitle );
				run("Erode");
				run("Dilate");
			} else {
				print( "   - no cleaning!" );
			}
			run("Close-"); // close holes

			//////////////////////
			// combine all masks
			//////////////////////
			print("   - combine masks");
			imageCalculator("AND", poreName, maskTitle);
			
			//////////////////////
			// Statistical analyse
			//////////////////////
			print(" - saving pore selection selection");
			saveAs("Tiff", outputDir_full + filename );
			rename( poreName );
			run("Analyze Particles...", "display clear");
			selectWindow("Results");
			saveAs("Text", outputDir_full + substring(filename, 0, lengthOf(filename)-4) + "_pores.csv");
			//close();

			//////////////////////
			// create color image to save
			//////////////////////
			compFileName = "composit_" + filename;
			selectWindow( compFileName );
			run("Split Channels");
			selectWindow("C1-" + compFileName);
			run("Invert");
			run("Merge Channels...", "c1=" + "C1-" + compFileName + " c2=" + poreName + " c4=" + "C2-" + compFileName + " create ignore");
		
			//////////////////////
			// close this file
			//////////////////////
			print( " closing file ..." );
			selectImage(imageId);
			close();
			print( "" );
		}
	}
	// exit script
	print("Done!");
	if ( arg != "" ) {
		run("Quit");
	}
}
