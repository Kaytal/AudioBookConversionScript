# Audiobook Conversion Documentation
Below are the steps to convert a chapterized MP3 into a single or multipart m4b
## Prereqs
- `ffmpeg`
- `ffprobe` (comes with `ffmpeg`)
- `jq` (comes with `ffmpeg` if you pulled it from Homebrew)

1. Run the splitfile.sh script on the file to pull all the individual chapters (and their titles) out of the original .mp3
```shell
# splitfile.sh
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
in=$1
extension=$1:e
out=$2
mkdir -p $out
metadata_source=${OVERRIDE_METADATA_SOURCE:-$in}

# Create a JSON formatted in memory object of all the chapters separated out
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
    # Sometimes you want to remove the prefix because the Chapters are clearly `Chapter 1`, `Chapter 2`, etc.
    # However in the case of "The Wandering Inn" there are multiple `interlude`s and `side stories` so to keep them in line
    # it's best to utilize the prefix
    # The `-metadata title=$title` is vital here. This "names" the "track" so that Audiobook applications can recognize the chapters
    splits+=(-c copy -c:a copy -map 0:a -metadata title=$title -ss $start -to $end "$out/${(l:$chapter_width::0:)n} - $title.$extension")
done
# This is done to get the "opening credits", "end credits" or "epilogue"
# Additionally this can be a nesting doll of the same input file. Check the filesize of the _last_ created file.
echo $chapters_arr[-1] | read start end title
splits+=(-c copy -c:a copy -map 0:a -metadata title=$title -ss $start "$out/${(l:$chapter_width::0:)n} - $title.$extension")

ffmpeg -i $in $splits
```
2. Take the newly created files and bind them into a single (or multiple) .m4b(s). I used AudioBookBinder but you can definitely use `ffmpeg` to marry the files. If this is a multipart book then I suggest adding `, Part X` at the end so that when you build the Album you know which part you're working with. Caveats I've found are that a single .m4b file can only be about < 16 hours in length. After that I've run into issues where it just stops at 16 hours and even if the end product is 50 hours long after hour 16 it's just blank noise.
3. After you've gotten the newly created .m4b(s) if you only have 1 file because your audiobook is less than 16 hours, congrats you're done. If not, however, you'll need to modify the tags to make it a "single" cohesive book inside an audiobook app like MacOS/iOS's `Book`s app.
You can view the Metadata for a file with `ffmpeg` like this:
```shell
ffmpeg -y -loglevel error -i input_file.m4b/.mp3 -f ffmetadata outputFile.txt
```
4. Open all the `.m4b`s you've created in `subler`. Using `subler` add the language to the audio track. Then add a `track#` metadata to the bottom list of existing metadata. `track` is written like `x/N` where `x` is the current part and `N` is the total number of parts. Additionally, when you created the `.m4b` in Audiobookbinder or `ffmpeg` you may have named it something like: "Foo Bar, Part 1". When you do that it makes the Name of the Audiobook AND the name of Album the same. If this is a multipart book you'll need to change the Album title to something the same across all parts. "Foo Bar", for instance. (Note: this can also be done in `ffmpeg` via the `-metadata track=1/4`)