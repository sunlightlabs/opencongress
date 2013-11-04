#!/bin/bash
if [ -d "$1" ]
  then
  data=$1
else
  echo 'data dir not found! fix DATA_PATH in your environment file'
  exit
fi
if [ ! -d "$data/govtrack/log" ]
then
  mkdir -p $data/govtrack/log
fi

if [ ! -e "$data/govtrack/log/govtrack-photo-rsync.log" ]
then
  touch $data/govtrack/log/govtrack-photo-rsync.log
fi
cd $data/govtrack

echo "\n\nrsyncing govtrack photos at `date`" >> log/govtrack-photo-rsync.log
rsync -avz --exclude '*px.jpeg' govtrack.us::govtrackdata/photos . >> log/govtrack-photo-rsync.log

cd photos

sizes=( 42 73 102 )
rad=( 3 5 7)
for dir in 0 1 2
do
  if [ ! -d "thumbs_${sizes[dir]}" ]
    then
    mkdir "thumbs_${sizes[dir]}"
  fi
done
 
for srcfile in $(find . -maxdepth 1 -name \*.jpeg -print | sort); do
    srcfile=$(basename "${srcfile}")
    for size in 0 1 2; do
        govtrack_id=$(basename "${srcfile}" jpeg)
        thumb_path="thumbs_${sizes[size]}/${govtrack_id}png"
        if [ ! -e "${thumb_path}" -o "${srcfile}" -nt "${thumb_path}" ]; then
            convert $srcfile -thumbnail ${sizes[size]} -depth 8 -quality 95 \
                \( +clone  -threshold -1 \
                -draw "fill black polygon 0,0 0,${rad[size]} ${rad[size]},0 fill white circle ${rad[size]},${rad[size]} ${rad[size]},0" \
                \( +clone -flip \) -compose Multiply -composite \
                \( +clone -flop \) -compose Multiply -composite \
                \) +matte -compose CopyOpacity -composite "${thumb_path}"

            ls -lh "${thumb_path}"
        fi
    done
done
