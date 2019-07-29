// Macro for ImageJ 1.52d for Windows
// written by Florian Kleiner 2019
// run from command line as follows
// ImageJ-win64.exe -macro "C:\path\to\remove_scalebar.ijm" "D:\path\to\data\|outputDirName|infoBarheight|metricScale|pixelScale"

function createInnerMask() {
	choice = showMessageWithCancel("Create inner Mask", "If there are large voids inside area of interest you can select them now using the polygone tool. Confirm the selection using the OK button. Or cancel the action using the Cancel button.");
	if ( choice ) {
		setTool("polygon");
		run("Fit Spline");
		run("Create Mask");
		// combine masks
		imageCalculator("AND create", "outerMask","innerMask");
		// TODO: Titel umbenennen
		choice = createInnerMask();
	}
	return choice;
}

macro "remove_SEMScaleBar" {
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
	print("  argument based image-scale: " + pixelScale + " px / " + metricScale + " nm");
	if ( metricScale == 0 || pixelScale == 0 ) {
		do_scaling = false;
		print("  No image-scaling set! Calculation only pixel values!");
	} else {
		do_scaling = true;
		scaleX = metricScale/pixelScale;
		print( "  Set scale 1 px = " + scaleX + " nm" );
	}
	print("Info bar height: " + infoBarHeight + " px");
	print("------------");
	
	//directory handling
	outputDir_Cut = dir + "/" + outputDirName + "/";
	File.makeDirectory(outputDir_Cut);
	list = getFileList(dir);
	
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
			
			//////////////////////
			// image constants
			//////////////////////
			width			= getWidth();
			height			= getHeight();
			
			//////////////////////
			// processing
			//////////////////////
			
			//selectWindow("Cryo+Harz_069-cut.tif");
			run("Non-local Means Denoising", "sigma=15 smoothing_factor=1 auto");
			setTool("polygon");
			// TODO: Nutzer muss Außenspline erstellen -> Alert + OK zum bestätigen
			run("Fit Spline");
			run("Create Mask");
			// TODO: Titel umbenennen
			// TODO: Nutzer muss Innenspline erstellen -> Alert + OK zum bestätigen und abbrechen zum verwerfen
			// TODO: Wenn OK:

				
			
			selectImage(imageId);
			run("Auto Local Threshold", "method=Phansalkar radius=15 parameter_1=0 parameter_2=0");
			imageCalculator("AND create", filename, "Mask");
			//selectWindow("Result of Cryo+Harz_069-cut.tif");
			run("Analyze Particles...", "display clear");
			//run("Distribution...", "parameter=Area or=57 and=0-0");

			//////////////////////
			// close this file
			//////////////////////
			print( "  closing file ..." );
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
