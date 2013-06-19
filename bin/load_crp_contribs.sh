#!/bin/bash

# This script cleans the contribution CSV files provided by OpenSecrets.
# It eliminates records that lack values in fields we require and it 
# removes columns that are not of interest to us. It then generates an SQL
# file suitable for loading the CSV files into the OpenCongress database.

function usage () {
    cmd=`basename $0`
    echo "${cmd} YEAR"
}

function load_pacs_file () {
    year="$1"
    suffix="${year:2}"
    pacs_file="pacs${suffix}.txt"
    last_pacs_file="pacs${suffix}.txt.last"

    if [ ! -e "${pacs_file}" ]; then
        echo "No such file ${pacs_file}"
        exit 1
    fi

    if [ ! -e "${last_pacs_file}" -o "${pacs_file}" -nt "${last_pacs_file}" ]; then
        # These columns are marked not null in the database so we throw away the records
        # missing values in those columns.
        grepfile=`mktemp`
        cat "${pacs_file}" \
            | csvgrep -c 1 -r '^$' -i -e 'latin2' -q '|' -d ',' \
            | csvgrep -c 2 -r '^$' -i -e 'latin2' \
            | csvgrep -c 3 -r '^$' -i -e 'latin2' \
            | csvgrep -c 5 -r '^$' -i -e 'latin2' \
            | csvgrep -c 6 -r '^$' -i -e 'latin2' \
            | csvgrep -c 9 -r '^$' -i -e 'latin2' \
            > "${grepfile}"

        mv "${grepfile}" "${last_pacs_file}"
    else
        echo "Skipping PAC contributions because ${last_pacs_file} is newer than ${pacs_file}"
    fi

    chmod ugo+r "${last_pacs_file}"
    fq_last_pacs_file=$(readlink -f "${last_pacs_file}")
    cat >> "${SQLFILE}" <<-ENDOFSQLPAC

        DELETE FROM crp_contrib_pac_to_candidate WHERE cycle = '${year}' ;

        COPY crp_contrib_pac_to_candidate
        FROM '${fq_last_pacs_file}'
        WITH CSV DELIMITER ',' QUOTE '"' ;
ENDOFSQLPAC
}

function load_indivs_file () {
    year="$1"
    suffix="${year:2}"
    indivs_file="indivs${suffix}.txt"
    last_indivs_file="indivs${suffix}.txt.last"
    if [ ! -e "${indivs_file}" ]; then
        echo "No such file ${indivs_file}"
        exit 1
    fi

    if [ ! -e "${last_indivs_file}" -o "${indivs_file}" -nt "${last_indivs_file}" ]; then
        grepfile=`mktemp`
        # These columns are marked not null in the database so we throw away the records
        # missing values in those columns. We have to use a separate process for each column
        # because csvgrep will output records where any of the specified columns match the
        # pattern.
        cat "${indivs_file}" \
            | csvgrep -c 1 -r '^$' -i -e 'latin2' -q '|' -d ',' \
            | csvgrep -c 2 -r '^$' -i -e 'latin2' \
            | csvgrep -c 4 -r '^$' -i -e 'latin2' \
            | csvgrep -c 9 -r '^$' -i -e 'latin2' \
            > "${grepfile}"

        # The 2012 files do not include the FecOccEmp field (column 20)
        # and OpenCongress does not require that column so we drop it
        # from older files and omit it from the schema.
        if [ "$year" -lt 2012 ]; then
            cutfile=`mktemp`
            csvcut -C 20 -e 'latin2' "${grepfile}" > "${cutfile}"
        else
            cutfile="${grepfile}"
        fi

        mv "${cutfile}" "${last_indivs_file}"
    else
        echo "Skipping individual contributions because ${last_indivs_file} is newer than ${indivs_file}"
    fi

    chmod ugo+r "${last_indivs_file}"
    fq_last_indivs_file=$(readlink -f "${last_indivs_file}")
    cat >> "${SQLFILE}" <<-ENDOFSQLIND
        DELETE FROM crp_contrib_individual_to_candidate WHERE cycle = '${year}' ;

        COPY crp_contrib_individual_to_candidate
        FROM '${fq_last_indivs_file}'
        WITH CSV DELIMITER ',' QUOTE '"' ;
ENDOFSQLIND
}

function fix_year_and_cycle_param () {
    if [ "${#1}" -eq 2 ]; then
        if [ "${1}" -ge 90 ]; then
            export year="19${1}"
        else
            export year="20${1}"
        fi
    elif [ "${#1}" -eq 4 ]; then
        if [ "${1}" -lt 1990 -o "${1}" -gt 2012 ]; then
            echo "This script only works with years between 1990 and 2012."
        else
            export year="${1}"
        fi
    else
        echo "Cannot fix $1"
    fi
}

function show_sql_file () {
    fq_sqlfile=$(readlink -f "crp${year}.sql")
    (echo "BEGIN ;" ;
     cat "${SQLFILE}" ;
     echo "COMMIT ;") > "${fq_sqlfile}"
    chmod ugo+r "${fq_sqlfile}"
    cat "${fq_sqlfile}"
    echo "To load new data, execute this SQL file against the database: ${fq_sqlfile}"
}

SQLFILE=`mktemp`

if [ "$#" -eq 1 ]; then
    fix_year_and_cycle_param $1
    if [ -z "${year}" ]; then
        exit 1
    fi
    load_indivs_file "${year}"
    load_pacs_file "${year}"
    if [ -s "${SQLFILE}" ]; then
        show_sql_file
    else
        echo "No SQL generated. Error?"
    fi
else
    usage
    exit 1
fi

