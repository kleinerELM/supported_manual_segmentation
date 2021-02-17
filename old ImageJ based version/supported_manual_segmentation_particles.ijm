// Macro for ImageJ 1.52d for Windows
// written by Florian Kleiner 2020
// run from command line as follows
// ImageJ-win64.exe -macro "C:\path\to\supported_manual_segmentation_particles.ijm" "D:\path\to\file.tif|thresholdType|thresholdStdMethod"

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
wekaLoaded = false;
enhanceContrast = false;
doColorClassification = false;
classPath = "D:\\Maps\\C3S 1-24h Images to be analysed\\cut\\24h Tile Set (3) (stitched)\\classifier.model";
wekaVersion = "3.2.33";

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
	outputDir_mixed_img = dir + "/WEKA_mix_images/";
	outputDir_segmented = dir + "/WEKA_segmentation_by_phase/";
	outputDir_propability = dir + "/WEKA_propabilty_maps_by_phase/";
	File.makeDirectory(outputDir_mixed_img);
	File.makeDirectory(outputDir_segmented);
	File.makeDirectory(outputDir_propability);
	
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
			//////////////////////"
			filename = getTitle();
			print( "----------------" );
			print( filename );
			baseName		= substring(filename, 0, lengthOf(filename)-4);
			cutName			= baseName + "-cut.tif";
			poreName		= "PoreBinary";
			maskTitle 		= "Mask";
			compositeTitle	= "Composite";
			
			//////////////////////
			// image constants
			//////////////////////
			//width			= getWidth();
			//height			= getHeight();
			
			//////////////////////
			// initial processing
			//////////////////////
			if ( useNLMDenoising ) {
				print(" - denoising");
				run("Non-local Means Denoising", "sigma=10 smoothing_factor=1");
				saveAs("Tiff", outputDir_mixed_img + "NLM_" + filename );
			} else {
				//run("Smooth");
			}
			if ( enhanceContrast ) {
				print(" - enhancing contrast");
				run("Enhance Contrast...", "saturated=0.3");
			}

			//////////////////////
			// try to segment pores
			//////////////////////
			print(" - WEKA Segmentation");
			startWeka();
			if ( doColorClassification ) {
				output_file = outputDir_mixed_img + "/result_" + baseName + ".png";
				if ( File.exists( output_file ) ) {
					print("   - output file already exists, skipping...");
				} else {
					call("trainableSegmentation.Weka_Segmentation.applyClassifier", dir, filename, "showResults=true", "storeResults=false", "probabilityMaps=false", "");
					call("trainableSegmentation.Weka_Segmentation.getResult");

					print("   - waiting...");
					wait(1000);
					selectWindow("Classification result");
					saveAs("PNG", outputDir_mixed_img + "/result_" + baseName + ".png" );
					close();
					print("   - colored map has been saved.");
				}
			} else {
				if ( fileIsAlreadyProcessed( outputDir_propability, baseName ) ) {
					print("   - output file already exists, skipping...");
				} else {
					//selectWindow("Trainable Weka Segmentation v" + wekaVersion);
					
					// process propability -> split stack, threshold using otsu
					call("trainableSegmentation.Weka_Segmentation.applyClassifier", dir, filename, "showResults=true", "storeResults=false", "probabilityMaps=true", "");
					print("searching for probability Maps");
					selectWindow("Classification result");
					//call("trainableSegmentation.Weka_Segmentation.getProbability");
					//selectWindow("Probability maps");
					sliceCount = nSlices;
					classLabelArray= newArray();
					for (i=1; i<=sliceCount; i++) {
						setSlice(i);
						classLabel = getMetadata("Label");
						classLabelArray = Array.concat(classLabelArray, classLabel);
						File.makeDirectory(outputDir_segmented + classLabel + "/");
						File.makeDirectory(outputDir_propability + classLabel + "/");
					}
					run("Stack to Images");
					for (i=0; i<sliceCount; i++) {
						print( "   - saving stack number " + i + " (" + classLabelArray[i] + ")" );
						selectWindow(classLabelArray[i]);
						saveAs("PNG", outputDir_propability + classLabelArray[i] + "/" + baseName + ".png" );
						print( "   - autoThreshold " + i + " (" + classLabelArray[i] + ")" );
						setAutoThreshold("Otsu");
						setOption("BlackBackground", true);
						run("Convert to Mask");
						run("Erode");
						run("Dilate");
						run("Invert");
						saveAs("PNG", outputDir_segmented + classLabelArray[i] + "/" + baseName + ".png" );
						close();
					}
				}
			}
			//print( "closing: Trainable Weka Segmentation v" + wekaVersion );
			//selectWindow("Trainable Weka Segmentation v" + wekaVersion);
			//close();





			//////////////////////
			// remove noise and holes from pore mask
			//////////////////////
			//if ( cleanupAsk ) { cleanup1 = getBoolean("Do you want to clean the result using Erode/Dilate?\nPress [Cancel] to stop the macro."); }
			//if ( cleanup1 ) {
			//	print( "   - cleaning pore selection" );
			//	run("Options...", "iterations=1 count=1 black do=Erode");
			//	//run("Erode");
			//	run("Dilate");
			//} else {
			//	print( "   - no cleaning!" );
			//	if ( cleanupAsk ) { cleanup4 = getBoolean("Do you want to run the 'Despeckle' operation?\nPress [Cancel] to stop the macro."); }
			//	if ( cleanup4 ) {
			//		print( "   - despeckle holes" );
			//		run("Despeckle");
			//		//run("Close-"); // close holes
			//	} else {
			//		print( "   - no despeckle!" );
			//	}
			//}
			
			// make shure only one iteration is selected
			//run("Options...", "iterations=1 count=1 black do=Nothing");

			




			
		
			//////////////////////
			// close this file
			//////////////////////
			//if ( thresholdType == 1 ) {
				print( " closing file ..." );
				selectImage(imageId);
				close();
			//}
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

function startWeka() {
	if ( wekaLoaded == false ) {
		print("load WEKA classification");
		run("Trainable Weka Segmentation");
		print("waiting...");
		wait(1000);
		//selectWindow("Trainable Weka Segmentation v3.2.33");
		call("trainableSegmentation.Weka_Segmentation.loadClassifier", classPath);
		
		//run("Trainable Weka Segmentation");
		//selectWindow("Trainable Weka Segmentation v" + wekaVersion);
		//call("trainableSegmentation.Weka_Segmentation.loadClassifier", classPath);
		wekaLoaded = true;
	}
}

function fileIsAlreadyProcessed( dir, baseName ) {
	result = false;
	subList = getFileList(dir);

	output_file = outputDir_mixed_img + "/result_" + baseName + ".png";
	for (k=0; k<subList.length; k++) {
		if (endsWith(subList[k], "/")) {
			subDir = ""+dir+subList[k];
			if ( File.exists( subDir + baseName + ".png" ) ) {
				result = true;
			}
		}
	}
	
	return result;
}

macro "supported_manual_segmentation_particles" {
	// check if an external argument is given or define the options
	arg = getArgument();
	if ( arg == "" ) {
		Dialog.create("Choose Options");
		Dialog.addMessage("Choose the threshold type (and method) for pore selection.") 
		
		Dialog.addCheckbox("Batch processing (directory).", doDirectory);
		Dialog.addCheckbox("Use non local mean denoising (else smooth).", useNLMDenoising);
		Dialog.addChoice("Threshold type:", thresholdTypeArray, thresholdTypeArray[thresholdType] );
		Dialog.addChoice("Normal threshold method:", thresholdStdMethodsArray, thresholdStdMethodsArray[thresholdStdMethod] );
		//Dialog.addMessage(	"For BSE-Images try " + thresholdTypeArray[0] + "\n" +
		//					"For TLD-Images try " + thresholdTypeArray[2] + " (Otsu or Triangle)");
		Dialog.addCheckbox("Color segmentation result (check) or propability map (uncheck)", useNLMDenoising);
	// Otsu (11) or Triangle (15)!
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
		doColorClassification = Dialog.getCheckbox();
		
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
		imageCount = 0;
		for (i=0; i<list.length; i++) {
			path = dir+list[i];
			if ( endsWith(path,".tif") ) {
				imageCount++;
			}
		}
		imagePosition = 0;
		// running main loop
		for (i=0; i<list.length; i++) {
			path = dir+list[i];
			// get all files
			// select only images
			if ( endsWith(path,".tif") ) {
				imagePosition++;
				print( "Processing image " + imagePosition + " of " + imageCount );
				//showProgress(imagePosition, imageCount);
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

