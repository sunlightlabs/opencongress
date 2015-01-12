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
