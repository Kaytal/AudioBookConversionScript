#!/bin/zsh
# Note: this is only good for CHAPTERIZED files. If the breaks come in the middle of a word,
# the result will sound bad.
#
# Note that other containers are also supported!
if [[ -z $1 || -z $2 ]]; then
    echo "Usage: $0 <in file> <out directory>" >&2
    exit 1
fi

# $1 = Name of File
# $2 = Directory for New Files
# $3 = 
in=$1
extension=$1:e
out=$2
PREFIX="${3:-true}" # Whether or not to prefix
mkdir -p $out
metadata_source=${OVERRIDE_METADATA_SOURCE:-$in}

chapters_str=$(ffprobe -i $metadata_source -print_format json -show_chapters -v 0 | \
    jq -r '.chapters[] | .start_time + " " + .end_time + " " + (.tags.title | sub(" "; "_"))')
chapters_arr=("${(@f)chapters_str}")
chapter_count=$#chapters_arr
# Prefix width, like 3 for "001", "002"...
chapter_width=$#chapter_count
n=0
splits=()
# Skip the end because the last chapter should not have the -to flag, in case
# the metadata is wrong. (It was in one case I saw)
for line in $chapters_arr[1,-2]; do
    ((n++))
    echo $line | read start end title
    if [ "$PREFIX" = "true" ]
    then
        prefix="${(l:$chapter_width::0:)n} - "
    else
        prefix=""
    fi
    splits+=(-c copy -c:a copy -map 0:a -metadata title=$title -ss $start -to $end "$out/$prefix$title.$extension")
done
if [ "$PREFIX" = "true" ]
then
    prefix="${(l:$chapter_width::0:)n} - "
else
    prefix=""
fi
echo $chapters_arr[-1] | read start end title
splits+=(-c copy -c:a copy -map 0:a -metadata title=$title -ss $start "$out/$prefix$title.$extension")

ffmpeg -i $in $splits