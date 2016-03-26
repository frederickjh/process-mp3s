# process-mp3s
Script to process church services mp3 files after recording with [Audio Grabber](http://www.audiograbber.org/) to set tags and also combine the tracks back into one church service mp3 file.

## Usage case

The church I attend uses [Audio Grabber](http://www.audiograbber.org/) to record church services in separate tracks for each section of the church service. Before we had only uploaded the sermons to the church's website. A request came in asking for full church services to be upload. However this was approved by the church board with the requirement that no testimonies be included.

This script was born from that request and requirements. I also use this opportunity to better set the mp3 id3 tags on the mp3 files also including the church's logo as the image for the mp3 files.

## Dependencies

* [mp3wrap](http://mp3wrap.sourceforge.net/)
* [eyeD3](http://eyed3.nicfit.net/)

On ubuntu you can install them in the **Ubuntu Software Center**. You need to have enabled the Ubuntu (universe) repository. Universe is community-maintained free and open-source software. Or you can do so on the command line with:
```
sudo apt-get install mp3wrap eyeD3
```

## Instructions for setup

Place this script in your computers $PATH. If you are using Ubuntu go to your home folder(**/home/username/**) and create a folder called **bin** if it does not exist and place in there. Ubuntu will add this folder to your path if it exists. Also make sure that the script is executable.

This script uses a separate configuration file. Copy the .process-mp3s to your home folder and change the tags for your configuration. eyeD3 is used for taging. Read its man page for more info on tags. mp3wrap is used to wrap the mp3 into a combined church service mp3.

Also configurable are two folders were files will be place. More information about these can be found in the "What the script does" section.

## Usage
This script takes one option the name of the folder with the mp3 tracks recorded from the church service. If you have spaces in your folder name surround the folder name with double quotes.
```
process-mp3s.sh 2016-03-25
```


## What the script does
* First the script will check dependencies and if the configuration file and image files exist.
* Next it will ask two questions:
	* Which track is the sermon?
	* Which tracks should be excluded? (From the upload version of the combined church service.)
* It will re-tag all tracks.
* It will create a combined church service mp3 with all tracks and place it in the **churchservicesfolder**.
* It will create a combined church service mp3 for upload excluding the tracks entered for exclusion and place it in the **uploadsfolder**.
* It will copy the sermon to the **uploadsfolder** and rename it.

## Gotchas
While I have tried to make this script as portable as possible, it does have some hard coded values that I have not taken the time to make portable.

The **parsefilename** filename function is based on my churches file-naming convention. Which is:
yyyy-mm-dd - pastor's name - ## - title.p3

Where:

* yyyy = 4 digit year
* mm = 2 digit month
* dd = 2 digit day of month
* pastor's name = pastor's name (artist)
* \## = 2 digit track number
* title = track title

This information is parse to be placed in the mp3 id3 tags. If you do not use the file-naming convention above this script may not work for you.

