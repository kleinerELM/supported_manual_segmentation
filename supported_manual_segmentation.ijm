// Macro for ImageJ 1.52d for Windows
// written by Florian Kleiner 2020
// run from command line as follows
// ImageJ-win64.exe -macro "C:\path\to\supported_manual_segmentation.ijm" "D:\path\to\file.tif|thresholdType|thresholdStdMethod"

// global definitions
thresholdTypeArray = newArray("Auto Local Threshold (Phansalkar)", "Robust Automatic Threshold Selection", "Normal Threshold" );
thresholdStdMethodsArray = getList("threshold.methods");
thresholdType = 0; // 0 = Auto Local Threshold ...
thresholdStdMethod = 0;
autoThresholdOuterMask = true;
useNLMDenoising = true;
crop=false;
cleanup0=false;
cleanup1=false;
cleanup2=false;
cleanup3=false;
cleanup4=false;
cleanupAsk=true;
manuallyRemoveAreas = true;
excludeBorderParticles = true;
doDirectory = false;

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
	run("Merge Channels...", "c1='" + maskTitle + "' c4='" + filename + "' create keep");
}

function mainProcess( filePath ) {
	dir = File.getParent(filePath);
	
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
			if ( useNLMDenoising ) {
				run("Non-local Means Denoising", "sigma=10 smoothing_factor=1");
			} else {
				run("Smooth");
			}
			run("Enhance Contrast...", "saturated=0.3");

			//////////////////////
			// remove noise and holes from pore mask
			//////////////////////
			if ( cleanupAsk ) { 
				cleanup0 = false;
				crop = getBoolean("Do you want to crop the image?\nEg if there is intense noise at the borders.\nPress [Cancel] to stop the macro.");
			}
			// auto or manual select remaining area
			if ( cleanup0 ) {
				makeRectangle(0, 0, width, height - 4);
				crop = true;
			} else if ( crop ) {
				setTool("rectangle");
				waitForUser("Information", "Select the area you want to keep.\nPress [OK] when ready..");
			}
			if ( crop ) {
				print(" - cropping");
				stype = selectionType();
				if ( stype == 0 ) { //rectangle
					run("Crop");
				}
			}
			
			//////////////////////
			// thresholding and cleanup
			//////////////////////
			if ( autoThresholdOuterMask ) {
				print(" - thresholding and cleanup");
				setAutoThreshold("Otsu dark");// Minimum
				run("Create Mask");
				run("Options...", "iterations=1 count=1 black do=Nothing"); // reset binary options
				run("Erode");
				run("Dilate");
				run("Dilate");
				run("Erode");
				run("Fill Holes");

				rename( maskTitle );
			} else {
				run("Select All");
				run("Create Mask");
				run("Select None");
			}
			run("Merge Channels...", "c1='" + maskTitle + "' c4='" + filename + "' create keep");
			selectWindow( compositeTitle );//selectImage(imageId);
			

			//////////////////////
			// make selections
			//////////////////////
			
			if ( autoThresholdOuterMask ) { // && ( !cleanupAsk || !crop ) ) {
				setTool("freehand");
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
				} else {
					if ( !autoThresholdOuterMask ) {
						print( "   - nothing selected, selecting everything!" );
						//setTool("rectangle");
						//run("Select All");
						//run("Create Mask");
						//run("Select None");
					} else {
						print( "   - nothing additionally selected, skipping." );
					}
				}
			}
			
			
			redrawComposit( compositeTitle, maskTitle, filename );

			selectWindow( maskTitle );
			run("Invert"); 
			selectWindow( compositeTitle );//selectImage(imageId);
			
			//rename( "outerMask" )
			if ( manuallyRemoveAreas ) {
				print(" - inner manual selection");
				createInnerMask( filename, compositeTitle );
			}
			//run("Select None"); // remove selection
			selectWindow( maskTitle );
			run("Invert"); // reinvert image to get the actual mask
			
			redrawComposit( compositeTitle, maskTitle, filename );
			print(" - saving manual selection...");
			saveAs("Tiff", outputDir_manual + "composit_" + filename );

			selectWindow( maskTitle );
			// try to elminate border effects
			//run("Options...", "iterations=4 count=1 black do=Erode");
			//saveAs("Tiff", outputDir_manual + filename );
			//rename( maskTitle );
			run("Clear Results");
			run("Set Measurements...", "area shape feret's redirect=None decimal=5"); // include shape diameter to determine circularity
			run("Measure");
			selectWindow("Results");
			saveAs("Text", outputDir_manual + substring(filename, 0, lengthOf(filename)-4) + "_area.csv");
			selectImage(imageId);

			//////////////////////
			// try to segment pores
			//////////////////////
			print(" - thresholding");
			print( "   - " + thresholdTypeArray[thresholdType] );
			
			if ( thresholdType == 0 ) {
				radius = 45; //10
				k = 0.1*substring(filename, 0, lengthOf(filename)-4);//0.25;
				r = 0.5;
				print( "     - radius=" + radius + " px, parameter 1=" + k + ", parameter 2=" + r );
				run("Auto Local Threshold", "method=Phansalkar radius=" + radius + " parameter_1=" + k + " parameter_2=" + r);
			} else if ( thresholdType == 1 ) {
				run("Robust Automatic Threshold Selection", "noise=25 lambda=3 min=354");
				run("Invert");
			} else if ( thresholdType == 2 ) {
				print( "     " + thresholdStdMethodsArray[thresholdStdMethod] );
				setAutoThreshold( thresholdStdMethodsArray[thresholdStdMethod] );
				run("Create Mask");
			}
			rename( poreName );
			
			//////////////////////
			// remove noise and holes from pore mask
			//////////////////////
			if ( cleanupAsk ) { cleanup1 = getBoolean("Do you want to clean the result using Erode/Dilate?\nPress [Cancel] to stop the macro."); }
			if ( cleanup1 ) {
				print( "   - cleaning pore selection" );
				run("Options...", "iterations=1 count=1 black do=Erode");
				//run("Erode");
				run("Dilate");
			} else {
				print( "   - no cleaning!" );
				if ( cleanupAsk ) { cleanup4 = getBoolean("Do you want to run the 'Despeckle' operation?\nPress [Cancel] to stop the macro."); }
				if ( cleanup4 ) {
					print( "   - despeckle holes" );
					run("Despeckle");
					//run("Close-"); // close holes
				} else {
					print( "   - no despeckle!" );
				}
			}
			if ( cleanupAsk ) { cleanup2 = getBoolean("Do you want to run the close operation?\nPress [Cancel] to stop the macro."); }
			if ( cleanup2 ) {
				print( "   - closing holes" );
				run("Options...", "iterations=2 count=4 black do=Close");
				//run("Close-"); // close holes
			} else {
				print( "   - no closing!" );
			}
			if ( cleanupAsk ) { cleanup3 = getBoolean("Do you want to run the 'Fill Holes' operation?\nPress [Cancel] to stop the macro."); }
			if ( cleanup3 ) {
				print( "   - 'Fill Holes'" );
				run("Fill Holes");
				//run("Close-"); // close holes
			} else {
				print( "   - no 'Fill Holes'!" );
			}
			
			// make shure only one iteration is selected
			run("Options...", "iterations=1 count=1 black do=Nothing");

			//////////////////////
			// combine all masks
			//////////////////////
			print("   - combine masks");
			imageCalculator("AND", poreName, maskTitle);
			selectWindow( maskTitle );
			close();
			
			//////////////////////
			// Statistical analyse
			//////////////////////
			rename( poreName );
			run("Clear Results");
			exclude = "";
			if ( excludeBorderParticles ) {
				exclude = "exclude ";
				print( "   - excluding border particles" );
			}
			run("Analyze Particles...", "display " + exclude + "clear"); //exclude: ignore particles contacting the border.
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
			run("Merge Channels...", "c1='C1-" + compFileName + "' c2='" + poreName + "' c4='C2-" + compFileName + "' create ignore");
			print(" - saving pore selection selection");
			saveAs("Tiff", outputDir_full + filename );
			
		
			//////////////////////
			// close this file
			//////////////////////
			if ( thresholdType == 1 ) {
				print( " closing file ..." );
				selectImage(imageId);
				close();
			}
			print( "" );
		}
	}
	if ( !doDirectory ) {
		// exit script
		print("Done!");
		if ( arg == "" ) {
			restart = getBoolean("Do you want to proceed?\nPress [Cancel] to stop the macro without closing ImageJ.");
			if ( restart ) {
				while (nImages>0) { 
					selectImage(nImages); 
					close(); 
				}
				filePath 		= File.openDialog("Choose a file");
				mainProcess( filePath );
			}
		} else {
			restart = false;
		}
		if ( !restart || arg != "" ) {
			run("Quit");
		}
	}
}

macro "supported_manual_segmentation" {
	// check if an external argument is given or define the options
	arg = getArgument();
	if ( arg == "" ) {
		Dialog.create("Choose Options");
		Dialog.addMessage("Choose the threshold type (and method) for pore selection.") 
		
		Dialog.addCheckbox("Batch processing (directory).", doDirectory);
		Dialog.addCheckbox("Use non local mean denoising (else smooth).", useNLMDenoising);
		Dialog.addChoice("Threshold type:", thresholdTypeArray, thresholdTypeArray[thresholdType] );
		Dialog.addChoice("Normal threshold method:", thresholdStdMethodsArray, thresholdStdMethodsArray[thresholdStdMethod] );
		Dialog.addMessage(	"For BSE-Images try " + thresholdTypeArray[0] + "\n" +
							"For TLD-Images try " + thresholdTypeArray[2] + " (Otsu or Triangle)");
	// Otsu (11) or Triangle (15)!
		Dialog.addCheckbox("Automatically try to create outer Mask.", autoThresholdOuterMask);
		Dialog.addCheckbox("Manually remove inner areas during processing?", manuallyRemoveAreas);
		Dialog.addCheckbox("Ask for cleanup options.", cleanupAsk);
		Dialog.addCheckbox("  Else: Auto crop bottom (4px)?", cleanup0);
		Dialog.addCheckbox("  Else: Do 'Erode/Dilate'?", cleanup1);
		Dialog.addCheckbox("        or: Do 'Despecle'?", cleanup4);
		Dialog.addCheckbox("  Else: Do 'Close-'?", cleanup2);
		Dialog.addCheckbox("  Else: Do 'Fill Holes'?", cleanup3);
		Dialog.addCheckbox("Exclude border particles from analysis?", excludeBorderParticles);
		Dialog.show();
		doDirectory = Dialog.getCheckbox();
		useNLMDenoising = Dialog.getCheckbox();
		thresholdTypeString = Dialog.getChoice();
		for (i=0; i<thresholdTypeArray.length; i++) {
			if (thresholdTypeArray[i] == thresholdTypeString){
				thresholdType = i;
			}
		}
		thresholdStdMethodString = Dialog.getChoice();
		for (i=0; i<thresholdStdMethodsArray.length; i++) {
			if (thresholdStdMethodsArray[i] == thresholdStdMethodString){
				thresholdStdMethod = i;
			}
		}
		autoThresholdOuterMask = Dialog.getCheckbox();
		manuallyRemoveAreas = Dialog.getCheckbox();

		cleanupAsk = Dialog.getCheckbox();
		cleanup0 = Dialog.getCheckbox();
		cleanup1 = Dialog.getCheckbox();
		cleanup4 = Dialog.getCheckbox();
		cleanup2 = Dialog.getCheckbox();
		cleanup3 = Dialog.getCheckbox();
		excludeBorderParticles = Dialog.getCheckbox();
		
		if ( doDirectory ) {
			dir = getDirectory("Choose a Directory");
		} else {
			filePath 		= File.openDialog("Choose a file");
		}
		//define number of slices for uniformity analysis
	} else {
		// Todo
		print("arguments found");
		arg_split = split(getArgument(),"|");
		filePath			= arg_split[0];
		thresholdType		= arg_split[1];
		thresholdStdMethod	= arg_split[2];
		autoThresholdOuterMask = arg_split[3];
	}
	
	print("Starting process using the following arguments...");
	print("  using threshold type: " + thresholdTypeArray[thresholdType] + " (" + thresholdType + ")" );
	print("  using threshold method: " + thresholdStdMethodsArray[thresholdStdMethod] + " (" + thresholdStdMethod + ")" );
	print("  auto threshold outer mask: " + autoThresholdOuterMask );
	
	if ( !doDirectory ) {
		print("  File: " + filePath);
		print("------------");
		mainProcess( filePath );
	} else {
		print("  Directory: " + dir);
		print("------------");
		//directory handling
		list = getFileList(dir);
		
		// running main loop
		for (i=0; i<list.length; i++) {
			path = dir+list[i];
			// get all files
			showProgress(i, list.length);
			// select only images
			if ( endsWith(path,".tif") ) {
				mainProcess( path );
				while (nImages>0) { 
					selectImage(nImages); 
					close(); 
				}
			}
		}
		// exit script
		print("Done!");
		if ( arg != "" ) {
			run("Quit");
		}
	}
}

