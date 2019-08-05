// Macro for ImageJ 1.52d for Windows
// written by Florian Kleiner 2019
// run from command line as follows
// ImageJ-win64.exe -macro "C:\path\to\remove_scalebar.ijm" "D:\path\to\data\|outputDirName|infoBarheight|metricScale|pixelScale"

function createInnerMask( filename, selectWindowName ) {
	selectWindow( selectWindowName );
	choice = getBoolean("If there are large voids inside area of interest you can select them now using the polygone tool.\nClick Yes to processd or cancel the action using the No button. Press Cancel to stop the macro.");
	if ( choice ) {
		waitForUser("Create inner Mask", "Select the inner mask. Click OK if ready.");
		setTool("polygon");
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
			
			//////////////////////
			// image constants
			//////////////////////
			width			= getWidth();
			height			= getHeight();
			
			//////////////////////
			// processing
			//////////////////////
			maskTitle = "Mask";
			compositeTitle = "Composite";
			print("denoising");
			run("Non-local Means Denoising", "sigma=15 smoothing_factor=1 auto");
			run("Enhance Contrast...", "saturated=0.3");
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

			
			setTool("polygon");
			//setBatchMode("show");
			print("outer manual selection");
			waitForUser("Select the outer area.", "Add something to outer mask.\nIf the red mask contains everything that should be selected press OK\nor select additional areas and press OK.");
			stype = selectionType();
			if ( stype == 2 ) { // 0=rectangle, 1=oval, 2=polygon, 3=freehand, 4=traced, 5=straight line, 6=segmented line, 7=freehand line, 8=angle, 9=composite, 10=point, -1=no selection. 
				run("Fit Spline");
			}
			if ( stype > 0 ) {
				print( "   - Selection found." );
				run("Create Mask");
				run("Select None"); // remove selection
				//TODO Combine masks
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
			print("saving manual selection...");
			saveAs("Tiff", outputDir_manual + "composit_" + filename );

			
			selectWindow( maskTitle );
			run("Set Measurements...", "area area_fraction redirect=None decimal=5");
			run("Measure");
			selectWindow("Results");
			saveAs("Text", outputDir_manual + substring(filename, 0, lengthOf(filename)-4) + "_area.csv");
			selectImage(imageId);
			print("thresholding");
			run("Auto Local Threshold", "method=Phansalkar radius=15 parameter_1=0 parameter_2=0");
			
			print("combine masks");
			imageCalculator("AND", maskTitle, filename);

			selectWindow( maskTitle );
			// remove noise and holes
			run("Erode");
			run("Dilate");
			run("Close-");
			
			
			print("saving pore selection selection");
			saveAs("Tiff", outputDir_full + filename );
			
			run("Analyze Particles...", "display clear");
			selectWindow("Results");
			saveAs("Text", outputDir_full + substring(filename, 0, lengthOf(filename)-4) + "_pores.csv");
			close();

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
