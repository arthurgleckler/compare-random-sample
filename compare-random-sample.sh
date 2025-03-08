#!/bin/bash

usage() {
   echo "Usage: $0 <dir1> <dir2> <sample_size>"
   exit 1
}

if [ "$#" -ne 3 ]; then
   usage
fi

DIR1="$1"
DIR2="$2"
SAMPLE_SIZE="$3"

if command -v fdfind &> /dev/null; then
    FD_CMD="fdfind"
else
    FD_CMD="fd"
fi

if [ ! -d "$DIR1" ]; then
   echo "First directory does not exist: $DIR1"
   usage
fi

if [ ! -d "$DIR2" ]; then
   echo "Second directory does not exist: $DIR2"
   usage
fi

if ! [[ "$SAMPLE_SIZE" =~ ^[0-9]+$ ]]; then
   echo "Sample size must be a positive integer"
   usage
fi

TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" 0 1 15
$FD_CMD --type f . "$DIR1" | shuf -n $SAMPLE_SIZE > "$TEMP_DIR/random-sample.txt"

SAMPLE_SIZE=$(wc -l < "$TEMP_DIR/random-sample.txt")

while read -r dir1_file; do
   relative_path="${dir1_file#$DIR1/}"
   dir2_file="$DIR2/$relative_path"

   echo -n Checking $relative_path...
   if [[ -f "$dir2_file" ]]; then
     dir1_checksum=$(shasum "$dir1_file" | awk '{ print $1 }')
     dir2_checksum=$(shasum "$dir2_file" | awk '{ print $1 }')

     if [[ "$dir1_checksum" != "$dir2_checksum" ]]; then
       echo
       echo "  MISMATCH"
       ((mismatch++))
     else
       echo " identical."
     fi
   else
     echo "  MISSING."
     ((mismatch++))
   fi
done < "$TEMP_DIR/random-sample.txt"
if [ -z "$mismatch" ]; then
  echo "All $SAMPLE_SIZE files sampled were identical."
elif [ "$mismatch" -eq 1 ]; then
  echo "There was 1 mismatch in $SAMPLE_SIZE samples."
else
  echo "There were $mismatch mismatches in $SAMPLE_SIZE samples."
fi
exit $(( mismatch ? 1 : 0 ))