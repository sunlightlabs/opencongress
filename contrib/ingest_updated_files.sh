#!/bin/bash

event_type="$1"
src_path="$2"
dest_path="$3"

function die () {
    echo $@
    exit 1
}

# Taken from: https://rvm.io/workflow/scripting
# Load RVM into a shell session *as a function*
if [[ -s "$HOME/.rvm/scripts/rvm" ]] ; then
    # First try to load from a user install
    source "$HOME/.rvm/scripts/rvm"
elif [[ -s "/usr/local/rvm/scripts/rvm" ]] ; then
    # Then try to load from a root install
    source "/usr/local/rvm/scripts/rvm"
else
    printf "ERROR: An RVM installation was not found.\n"
    exit 1
fi

cd $HOME/src/current || die "Unable to find ~/src/current"

# We only care about the moved event because we `mv` the .updated files into
# place to ensure atomicity; we avoid multiple modified events for large files.
if [ "${event_type}" == "moved" ]; then
    if [ "${dest_path}" == "/projects/opencongress-us-scrapers/tmp/bills.updated" ]; then
        echo "Importing bills listed in ${dest_path}"
        rails runner bin/import_bills_feed.rb < "${dest_path}"
    fi

    if [ "${dest_path}" == "/projects/opencongress-us-scrapers/tmp/amendments.updated" ]; then
        echo "Importing amendments listed in ${dest_path}"
        rails runner bin/import_amendments_feed.rb < "${dest_path}"
    fi

    if [ "${dest_path}" == "/projects/opencongress-us-scrapers/tmp/votes.updated" ]; then
        echo "Importing roll call votes listed in ${dest_path}"
        rails runner bin/import_votes_feed.rb < "${dest_path}"
    fi
fi

# Since we don't have abbreviated import routines for the files these scrapers produce,
# the post-scrape script just touches the file, so we watch for the created event.
if [ "${event_type}" == "created" ]; then
    if [ "${src_path}" == "/projects/opencongress-us-scrapers/tmp/committee_meetings.updated" ]; then
        echo "Importing committee meetings."
        rails runner bin/import_committee_meetings.rb
    fi

    if [ "${src_path}" == "/projects/opencongress-us-scrapers/tmp/fdsys_crpt.updated" ]; then
        echo "Importing committee reports."
        rails runner bin/import_committee_reports.rb
    fi
fi

