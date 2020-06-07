#!/bin/bash
PS4=':${LINENO} + '
#set -x

# Add gettext.sh functionality to the text translation capablities to the script.
source gettext.sh
#Set get text variables
export TEXTDOMAIN=$(basename $0) # Name of this script
export TEXTDOMAINDIR=$(dirname "$(readlink -f "$0")")/locale # Location of this script

# Set the version wildcard for eyeD3 that this version should be compatible with.
# Enter the version with spaces where the periods normally would be.
eyed3versionok=(0 8 10)

# Where are the mp3 to process?
mp3filesfolder="$1"
# failsafe - fall back to current directory
[ "${mp3filesfolder}" == "" ] && mp3filesfolder="$(pwd)"
# List of programs this script needs.
dependencies="mp3wrap eyeD3 sed find"
# Temporary mp3 wrap filename to use. We will rename it to get rid of the MP3WRAP in the filename.
tempmp3file="temp_MP3WRAP.mp3"
# Symbol to replace with a dash(-) in id3 tags harvested from the filenames.
# See function dashsymbolreplacementintags() and dashsymbolreplacementinfilenames() below for more information. Be careful what you use for a symbol. ie. * does not work.
dashreplacementsymbol="__"

# get configuration
function getconfiguration(){
if [ -f "$HOME/.process-mp3s" ]; then
  source $HOME/.process-mp3s
else
  echo -e "${red}$(eval_gettext "Configuration file") $HOME/.process-mp3s $(eval_gettext "not found!  Aborting!")${NC}"
fi
}
#Check if we have all the programs we need to do our job.
function checkdependencies(){
missing=0
for dependency in $dependencies;
  do
    command -v $dependency >/dev/null 2>&1 || {
      echo -e >&2 "${yellow}$(eval_gettext "I require ")${red}$dependency ${yellow}$(eval_gettext "but it's not installed.")${NC}"
      let missing=missing+1
      }
  done
  if [[ $missing -ne 0 ]]; then
    echo -e "${yellow}***** ${red}$missing $(eval_gettext "dependencies are missing aborting!")${yellow} *****${NC}"
    exit $missing
  fi 
}
function checkeyed3version() {
# Check the version of eyeD3. We have only tested with version 0.6.18. The next version 0.7.0 breaks the API and may require a rewrite.
    eyed3version=($(eyeD3 --version | head -n 1| awk '{print $2}'| awk -F "." '{print $1}'' ''{print $2}'' ''{print $3}'))
# Newer versions of eyeD3 output the version number to  stderr instead of stdout?! Also only one line with just the version number.
if [ -z ${eyed3version[1]} -o -z ${eyed3version[0]} ] ; then
  eyed3version=($(eyeD3 --version 2>&1 | awk -F "." '{print $1}'' ''{print $2}'' ''{print $3}'))
fi
if [ ${eyed3version[1]} -gt ${eyed3versionok[1]} -o ${eyed3version[1]} -lt ${eyed3versionok[1]} ]; then
    echo -e "${red}$(eval_gettext "This version of eyeD3, ")${yellow}${eyed3version[0]}.${eyed3version[1]}.${eyed3version[2]}${red}$(eval_gettext " is of a different minor version than the tested version of ")${green}${eyed3versionok[0]}.${eyed3versionok[1]}.${eyed3versionok[2]}.${NC}"
    echo -e "${red}$(eval_gettext "The release notes for ")${yellow}0.7.0${red}$(eval_gettext " state the following:")${NC}"
    echo -e "${yellow}$(eval_gettext "This release is NOT API compatible with 0.6.x. The majority of the command line interface has been preserved although many options have either changed or been removed.")${NC}"
    echo -e "${green}https://github.com/nicfit/eyeD3/blob/c68a88751e8d84408824cbf6c2b53da157bf5785/HISTORY.rst#070---11152012-be-quiet-and-drive${NC}"
    echo -e "The next minor version of eyeD3, 0.8.x also states it has breaking changes."
    echo -e "${red}Aborting! Upgrade to the next version of this ${yellow}process-mp3s.sh${red} script (${yellow}1.0.0${red}) or higher if available or get version ${green}${eyed3versionok[0]}.${eyed3versionok[1]}.${eyed3versionok[2]}${red} of ${yellow}eyeD3${red} to run with this version of ${yellow}process-mp3s.sh${red}.${NC}"
    exit 1
fi
}
# Check if the folders we want to place files into exist, if not create them.
function checkiffoldersexist(){
  if [ ! -d ${churchservicesfolder} ]; then
    mkdir -p ${churchservicesfolder}
  fi
  if [ ! -d ${uploadsfolder} ]; then
    mkdir -p ${uploadsfolder}
  fi
}
function loadcolor(){
# Colors  http://wiki.bash-hackers.org/snipplets/add_color_to_your_scripts
# More info about colors in bash http://misc.flogisoft.com/bash/tip_colors_and_formatting
esc_seq="\x1b["  #In Bash, the <Esc> character can be obtained with the following syntaxes:  \e  \033  \x1B
NC=$esc_seq"39;49;00m" # NC = Normal Color
red=$esc_seq"31;01m"
green=$esc_seq"32;00m"
yellow=$esc_seq"33;01m"
blue=$esc_seq"34;01m"
magenta=$esc_seq"35;01m"
cyan=$esc_seq"36;01m"
}
function isitanumber(){
  bad=0
  re='^[0-9]+$'
  if ! [[ $1 =~ $re ]] ; then
    echo -e "${red}$(eval_gettext "Error:") ${yellow}${1}${red} $(eval_gettext "is not a number")${NC}"
    bad=1
  fi
}
function whattrackisthesermon(){
  sermontrack=""
  while [ -z $sermontrack ]; do
  echo -ne "${yellow}>>> ${NC}$(eval_gettext "Please enter the track number of the sermon.") ${yellow}>>> ${NC}"
  read -r sermontrack
  isitanumber $sermontrack
  if [ $bad -ne 0 ]; then
    sermontrack=""
  fi
 done
 # If a single digit is entered add a zero in front of it.
 if [ ${#sermontrack} = 1 ]; then
   sermontrack="0$sermontrack"
 else
   sermontrack="$sermontrack"
 fi
}
function whattracksshouldnotbeincluded(){
  echo -ne "${yellow}>>> ${NC}$(eval_gettext "Please enter the tracks that should NOT be included in the mp3 of the whole service that will be uploaded to the website separated by spaces.") ${yellow}>>> ${NC}"
  read -a dontincludetracks
  
# get length of an array
dLen=${#dontincludetracks[@]}
# Check that we got number for tracks and not something else
for (( d=0; d<${dLen}; d++ ));  
do
  isitanumber ${dontincludetracks[$d]}
  if [ $bad -ne 0 ]; then
    echo -e "${red}$(eval_gettext "Aborting try again with track numbers!")${NC}"
    exit
  fi
done
 
# use for loop read all filenames
for (( d=0; d<${dLen}; d++ ));  
do
# If a single digit is entered add a zero in front of it.
   if [ ${#dontincludetracks[$d]} = 1 ]; then
     dontincludetracks[$d]="0${dontincludetracks[$d]}"
   else
     dontincludetracks[$d]="${dontincludetracks[$d]}"
   fi
done
}

function sanitizefilename(){
  # Get just the filename from the path the strip off the ./ at the beginning and then the .mp3 from the end (everything after the last period(.)).
  sanitizedfilename=$(basename "$unsanitizedfilename" | sed 's/^\.\///g' | sed s/\.[^\.]*$//)
}
function trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

function doesimagefileexist(){
  if [ ! -f "${id3image}" ]; then
    continue="no"
    until [ "$continue" = "yes" ]; do
      echo -e "${yellow}>>> ${NC}${red}$(eval_gettext "Image file") ${id3image} $(eval_gettext "to add to mp3 id3 tag does not exist!") ${yellow}>>> ${NC}"
      echo -e "${yellow}>>> ${NC}${red}$(eval_gettext "Please replace") ${id3image} $(eval_gettext "so it will be addded to the mp3's id3 tags.") ${yellow}>>> ${NC}"
      echo -ne "${yellow}>>> ${NC}$(eval_gettext "Do you want to continue and add the tags without the image file?") ${id3image} ${yellow}>>> ${NC} ${red}[N/y]${NC} "
      read -r response
      response=${response,,}    # tolower
        if [[ $response !=  "y" && $response != "Y"  && $response != "yes" && $response != "Yes" ]]; then
           echo -e "${red}$(eval_gettext "User aborted script! Now exiting!")${NC}"
          exit
        else
          addimagetag="no"
          continue=yes
        fi
    done
  else
    addimagetag="yes"
  fi
}

function loadfilenamesinarray(){
# save and change IFS 
OLDIFS=$IFS
IFS=$'\n'
 
# read all mp3 file names into an array, except those that have Gottesdienst in them as they are the combine mp3 and we will handle them later, we also sort them before stuffing them in our array
fileArray=($(find "${mp3filesfolder}" -type f -regex '.*.mp3' ! -name '* - Gottesdienst.mp3' |sort))
 
# restore it 
IFS=$OLDIFS
}
function whatsinthearray(){
echo -e "${yellow}=========================================================================${NC}"
# get length of an array
tLen=${#fileArray[@]}

for (( i=0; i<${tLen}; i++ ));
do
arrayitem="${fileArray[$i]}"
echo "$arrayitem"
done
echo -e "${yellow}=========================================================================${NC}"
}
# Parses the mp3 filenames to get the info contain therein. 
function parsefilename(){
# get length of an array
tLen=${#fileArray[@]}
 
# use for loop read all filenames
for (( i=0; i<${tLen}; i++ ));
do
  OLDIFS=$IFS
  # Go through using dash (-) as the separator.
  IFS=$'-'
  unsanitizedfilename="${fileArray[$i]}"
  sanitizefilename
  #Read the split words into an array based on dash delimiter
  declare -a filenamearraysplitbydashes
  read -a filenamearraysplitbydashes <<< "$sanitizedfilename"
  year=$(trim ${filenamearraysplitbydashes[0]})
  month=$(trim ${filenamearraysplitbydashes[1]})
  day=$(trim ${filenamearraysplitbydashes[2]})
  artist=$(trim ${filenamearraysplitbydashes[3]})
  track=$(trim ${filenamearraysplitbydashes[4]})
  # get rid of the year, month, day, artist, and track array elements so
  # all that is left is the track title element(s) that would have been
  # truncated at the first dash.
  unset filenamearraysplitbydashes[0]
  unset filenamearraysplitbydashes[1]
  unset filenamearraysplitbydashes[2]
  unset filenamearraysplitbydashes[3]
  unset filenamearraysplitbydashes[4]
  title=$(trim ${filenamearraysplitbydashes[@]})
  IFS=$OLDIFS
  dashsymbolreplacementintags
  makeid3tags
  setid3tags
  dashsymbolreplacementinfilenames
done
}
### Dash replacement feature
# Since we use dashes to divide up the file name
# in to id3 tags we cannot use dashes in the id3 tags, otherwise it messes
# up our tags. To allow dashes we allow a replacement symbol to be entered
# which we will replace with a dash in this function after the tag information
# has already been split out.
function dashsymbolreplacementintags(){
  for arg in title artist track; do
    eval value=\$$arg
# If you're relying on bash/ksh/zsh, you can make the replacements inside the shell with the ${VARIABLE//PATTERN/REPLACEMENT} construct.
    value=${value//${dashreplacementsymbol}/-}
    eval $arg=\$value
  done
}
### After tagging the files we can now safely rename them by replacing the dashreplacementsymbol with dashes in the filenames.
function dashsymbolreplacementinfilenames() {
  filenamewithdashreplacementsmade=${unsanitizedfilename//${dashreplacementsymbol}/-}
  if [ "${unsanitizedfilename}" != "${filenamewithdashreplacementsmade}" ]; then
    mv "${unsanitizedfilename}" "${filenamewithdashreplacementsmade}"
  fi
}
# Takes the info we have collected and rearranges it to set the id3 tags the way we want.
function makeid3tags(){
  id3title="$title"
  id3album="${year}-${month}-${day} ${artist}"
  ## All eyeD3 date options (-Y, --release-year excepted) follow ISO 8601 format. This is
  ## yyyy-mm-ddThh:mm:ss  The year is required, and each component thereafter is optional.
  id3year=$year
  id3recordingdate="${year}-${month}-${day}"
  id3track=$track
  id3combinetracktotal=${#fileArray[@]}
}

function setid3tags(){
  # Remove URL tag  and embedded images from mp3s so we can then add our own.
  eyeD3 --user-url-frame="WXXX:" --remove-all-images "${unsanitizedfilename}" 
  # Check if we are including the image tag or not.
  if [ "${addimagetag}" = "yes" ]; then
  eyeD3 --artist "${id3artist}" --album "${id3album}" --title "${id3title}" --track ${id3track} --track-total ${id3combinetracktotal} --publisher "${id3publisher}" --text-frame="TCOP:${id3copyright}" --release-year ${id3year} --recording-date ${id3recordingdate} --orig-release-date ${id3recordingdate} --release-date ${id3recordingdate} --encoding-date ${id3recordingdate} --tagging-date ${id3recordingdate} --user-url-frame="WXXX:${id3url}" "--add-image=${id3image}:FRONT_COVER:Regichile Logo" "${unsanitizedfilename}"
  elif [ "${addimagetag}" = "no" ]; then
    eyeD3 --artist "${id3artist}" --album "${id3album}" --title "${id3title}" --track ${id3track} --track-total ${id3combinetracktotal} --publisher "${id3publisher}" --text-frame="TCOP:${id3copyright}" --release-year ${id3year} --recording-date ${id3recordingdate} --orig-release-date ${id3recordingdate} --release-date ${id3recordingdate} --encoding-date ${id3recordingdate} --tagging-date ${id3recordingdate} --user-url-frame="WOAR:${id3url}" "${unsanitizedfilename}"
  fi
}

function findtracksnottoincludearrayindex(){
  # get length of an array
  tracksLen=${#dontincludetracks[@]}
# use for loop read filenames to not include
  for (( t=0; t<${tracksLen}; t++ ));
do
  # get length of an array
  tLen=${#fileArray[@]}
 tracktodelete="${dontincludetracks[$t]}"
# use for loop read all filenames
for (( i=0; i<${tLen}; i++ ));
  do
    OLDIFS=$IFS
    # Go through using dash (-) as the separator.
    IFS=$'-'
    unsanitizedfilename="${fileArray[$i]}"
    # If we have already emptied a place in the array skip over it.
    if [ -z "${unsanitizedfilename}" ]; then
      continue
    fi
    sanitizefilename
    set $sanitizedfilename
    track=$(trim $5)
    IFS=$OLDIFS
  if [ $track = $tracktodelete ]; then
    removetrack
  fi
  done
done
}

function removetrack(){
 unset "fileArray[$i]"
}

# Finds the sermon 
function findsermon(){
# get length of an array
tLen=${#fileArray[@]}
 
# use for loop read all filenames
for (( i=0; i<${tLen}; i++ ));
do
  OLDIFS=$IFS
  # Go through using dash (-) as the separator.
  IFS=$'-'
  unsanitizedfilename="${fileArray[$i]}"
  sanitizefilename
  set $sanitizedfilename
  track=$(trim $5)
  IFS=$OLDIFS
  if [ ${track} = ${sermontrack} ]; then
    #Read the split words into an array based on dash delimiter
    declare -a sermonfilenamearraysplitbydashes
    OLDIFS=$IFS
    # Go through using dash (-) as the separator.
    IFS=$'-'
    read -a sermonfilenamearraysplitbydashes <<< "$sanitizedfilename"
    sermonyear=$(trim ${sermonfilenamearraysplitbydashes[0]})
    sermonmonth=$(trim ${sermonfilenamearraysplitbydashes[1]})
    sermonday=$(trim ${sermonfilenamearraysplitbydashes[2]})
    sermonartist=$(trim ${sermonfilenamearraysplitbydashes[3]})
    sermontrack=$(trim ${sermonfilenamearraysplitbydashes[4]})
    # get rid of the year, month, day, artist, and track array elements so
    # all that is left is the track title element(s) that would have been
    # truncated at the first dash.
    unset sermonfilenamearraysplitbydashes[0]
    unset sermonfilenamearraysplitbydashes[1]
    unset sermonfilenamearraysplitbydashes[2]
    unset sermonfilenamearraysplitbydashes[3]
    unset sermonfilenamearraysplitbydashes[4]
    sermontitle=$(trim ${sermonfilenamearraysplitbydashes[@]})
    IFS=$OLDIFS
    sermonfile="${unsanitizedfilename}"
    # Replace dashreplacmentsymbol in sermonfile and sermontitle
    sermontitle=${sermontitle//${dashreplacementsymbol}/-}
    sermonfile=${sermonfile//${dashreplacementsymbol}/-}
    # Now set the filename without dashes in the fileArray so we can get the new filename when we later combine mp3 files.
    fileArray[$i]="${sermonfile}"
    break
  fi 
done
}
function combinemp3s(){
  if [ -n $1 ] && [ "$1" = "internet" ]; then
    echo -e "${yellow} >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $(eval_gettext "Combining MP3s for upload to the Internet.") >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>${NC}"
  else
    echo -e "${yellow} >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $(eval_gettext "Combining MP3s for copying to USB devices locally.") >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>${NC}"
  fi
  echo ""
  mp3wrap "${tempmp3file}" "${fileArray[@]}"
}
# Takes the info we have collected and rearranges it to set the id3 tags the way we want.
function makecombinemp3id3tags(){
  id3combinetitle="$sermontitle"
  id3combinealbum="${sermonyear}-${sermonmonth}-${sermonday} ${sermonartist}"
  ## All eyeD3 date options (-Y, --release-year excepted) follow ISO 8601 format. This is
  ## yyyy-mm-ddThh:mm:ss  The year is required, and each component thereafter is optional.
  id3combineyear=$sermonyear
  id3combinerecordingdate="${sermonyear}-${sermonmonth}-${sermonday}"
  id3combinetrack="1"
}
function renameandtagcombinemp3(){
  churchservicefilename="${sermonyear}-${sermonmonth}-${sermonday} - ${sermonartist} - ${sermontitle} - Gottesdienst"
  if [ -n $1 ] && [ "$1" = "internet" ]; then
    # underscore at end of name means Internet version and Zeugnis have not been included.
    combinedmp3file="${uploadsfolder}${churchservicefilename}_.mp3" 
  else
    combinedmp3file="${churchservicesfolder}${churchservicefilename}.mp3"
  fi
  mv "${tempmp3file}" "${combinedmp3file}"
  # Remove URL tag from mp3wrap so we can then add our own.
  eyeD3 --user-url-frame="WXXX:" "${combinedmp3file}"
  # Check if we are including the image tag or not.
  if [ "${addimagetag}" = "yes" ]; then
  eyeD3 --artist "${id3combineartist}" --album "${id3combinealbum}" --title "${id3combinetitle}" --track ${id3combinetrack} --track-total ${id3combinetrack} --publisher "${id3publisher}" --text-frame="TCOP:${id3copyright}" --release-year ${id3combineyear} --recording-date ${id3combinerecordingdate} --orig-release-date ${id3combinerecordingdate} --release-date ${id3combinerecordingdate} --encoding-date ${id3combinerecordingdate} --tagging-date ${id3combinerecordingdate} --user-url-frame="WOAR:${id3url}" "--add-image=${id3image}:FRONT_COVER:Regichile Logo" "${combinedmp3file}"
  elif [ "${addimagetag}" = "no" ]; then
  eyeD3 --artist "${id3combineartist}" --album "${id3combinealbum}" --title "${id3combinetitle}" --track ${id3combinetrack} --track-total ${id3combinetrack} --publisher "${id3publisher}" --text-frame="TCOP:${id3copyright}" --release-year ${id3combineyear} --recording-date ${id3combinerecordingdate} --orig-release-date ${id3combinerecordingdate} --release-date ${id3combinerecordingdate} --encoding-date ${id3combinerecordingdate} --tagging-date ${id3combinerecordingdate} --user-url-frame="WOAR:${id3url}" "${combinedmp3file}"
  fi
}
function copyfileforupload(){
  # Copy and rename the sermon to the uploadsfolder
  cp "${sermonfile}" "${uploadsfolder}/${sermonyear}-${sermonmonth}-${sermonday} - ${sermonartist} - ${sermontitle}.mp3"
}
finished(){
  echo -e "${red}<>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <>< <><  ${yellow}>°)))><${NC} ¸.·¯¯·.¸¸.·¯¯·.¸¸.·"
  echo ""
  echo -e "${yellow}>>> ${NC}$(eval_gettext "The combined church service MP3 file has been placed in")  ${red}${churchservicesfolder}${NC}."
  echo -e "${yellow}>>> ${NC}$(eval_gettext "The sermon and combined service MP3 files for uploading have been copied to") ${red}${uploadsfolder}${NC}."
  echo ""
  echo -e "${yellow}>>> ${NC}$(eval_gettext "All done processing the MP3 files in") ${yellow}${mp3filesfolder}${NC}."
  echo -e "${yellow}>>> ${red}$(eval_gettext "Don't forget to upload the created files!")${NC}"
}

# Testing functions not used in the script during normal use.
function testecho(){
  echo "Year is: $year"
  echo "Month is: $month"
  echo "Day is: $day"
  echo "Artist is: $artist"
  echo "Track number is: $track"
  echo "Title is: $title"
  echo "+++++++++++++++++++++++"
  echo "id3title is: $id3title"
  echo "id3artist is: $id3artist"
  echo "id3album is: $id3album"
  echo "id3year is: $id3year"
  echo "id3track is: $id3track"
  echo "id3image is: $id3image"
  echo "======================="
}
function testechosermon(){
  echo "-----------------------"
  echo "Sermon title is: $sermontitle"
  echo "Sermon artist is: $sermonartist"
  echo "Sermon track is: $sermontrack"
  echo "Year is: $sermonyear"
  echo "Month is: $sermonmonth"
  echo "Day is: $sermonday"
  echo "Sermon file is: $sermonfile"
}
#############  MAIN PROGRAM #################
loadcolor
checkdependencies
checkeyed3version
getconfiguration
checkiffoldersexist
doesimagefileexist
loadfilenamesinarray
whatsinthearray
whattrackisthesermon
whattracksshouldnotbeincluded
parsefilename
findsermon
# Make combined church service with all files.
combinemp3s
makecombinemp3id3tags
renameandtagcombinemp3
# Make combined church service for Internet with excluded files.
findtracksnottoincludearrayindex
combinemp3s internet
renameandtagcombinemp3 internet
copyfileforupload
finished
