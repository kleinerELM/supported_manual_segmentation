// Macro for ImageJ 1.52d for Windows
// written by Florian Kleiner 2019
// run from command line as follows
// ImageJ-win64.exe -macro "C:\path\to\remove_scalebar.ijm" "D:\path\to\data\|infoBarheight|metricScale|pixelScale"

macro "add_ScaleBar" {
	// check if an external argument is given or define the options
	arg = getArgument();
	if ( arg == "" ) {
		dir = getDirectory("Choose a Directory");
	}
	print("Starting process using the following arguments...");
	print("  Input Directory: " + dir);
	
	//directory handling
	outputDir = dir + "/scalebar/";
	File.makeDirectory(outputDir);
	print("  Output Directory: " + outputDir);

	print("------------");
	
	list = getFileList(dir);
	// running main loop
	//setBatchMode(true);
	for (i=0; i<list.length; i++) {
		path = dir+list[i];
		// get all files
		showProgress(i, list.length);
		// select only images
		if (!endsWith(path,"/") && ( endsWith(path,".tif") ) ) {
			open(path);
			imageId = getImageID();
			// get image id to be able to close the main image
			if (nImages>=1) {
				//////////////////////
				// name definitions
				//////////////////////
				filename = getTitle();
				print( filename );//+ " (" + imageId + ")" );
				baseName		= substring(filename, 0, lengthOf(filename)-4);
				
				//////////////////////
				// image constants
				//////////////////////
				width			= getWidth();
				height			= getHeight();
				
				//////////////////////
				// processing
				//////////////////////
				print( "  convert to RGB..." );

				run("Stack to RGB");
				flatImageId = getImageID();
				selectImage(imageId);
				close();

				print( "  adding scalebar ..." );

				run("Scale Bar...", "width=1000 height=5 font=18 color=White background=None location=[Lower Right] bold overlay");
				saveAs("Tiff", outputDir + baseName + ".tif" );
				saveAs("Jpeg", outputDir + baseName + ".jpg" );

				//////////////////////
				// close this file
				//////////////////////
				print( "  closing file ..." );
				selectImage(flatImageId);

				close();
				print( "" );
			}
		}
	}
	// exit script
	print("Done!");
	if ( arg != "" ) {
		run("Quit");
	}
}