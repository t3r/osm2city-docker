#!/bin/bash
set -euxo pipefail

function cleanup {
	echo "cleanup"
}

trap cleanup EXIT

WEST=
EAST=
SOUTH=
NORTH=
DATABASE=
JSON=
TEN=
ONE=
TILE=

usage() { 
  echo "Usage: $0 --input something.osm.pbf [--database dbname] [--east -120  --west -130 --south 30 --north 40]" 1>&2; 
  echo "Short usage: $0 -i something.osm.pbf [-d dbname] [-e -120  -w -130 -s 30 -n 40]" 1>&2; exit 1; 
}

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    '--input')   set -- "$@" '-i'   ;;
    '--database')   set -- "$@" '-d'   ;;
    '--east')   set -- "$@" '-e'   ;;
    '--west')   set -- "$@" '-w'   ;;
    '--south')   set -- "$@" '-s'   ;;
    '--north')   set -- "$@" '-n'   ;;
    '--json')   set -- "$@" '-j'   ;;
    '--10x10')   set -- "$@" '-t'   ;;
    '--1x1')     set -- "$@" '-o'   ;;
    '--tile')    set -- "$@" '-l'   ;;
    '--help')   set -- "$@" '-h'   ;;
    *) set -- "$@" "$arg" ;;
  esac
done

# Parse short options
OPTIND=1
while getopts "i:j:d:e:w:s:n:t:o:l:h" opt
do
  case "$opt" in
    'd') DATABASE=$OPTARG ;;
    'e') EAST=$OPTARG ;;
    'w') WEST=$OPTARG ;;
    's') SOUTH=$OPTARG ;;
    'n') NORTH=$OPTARG ;;
    'j') JSON=$OPTARG ;;
    't') TEN=$OPTARG ;;
    'o') ONE=$OPTARG ;;
    'l') TILE=$OPTARG ;;
    'h') usage ;;
    '?') usage ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters
. $(dirname $0)/boundsparser.sh
test -n "$DATABASE" && export PGDATABASE=$DATABASE
O2C_PROCESSES=${O2C_PROCESSES:-1}
/usr/bin/python3 /app/osm2city/build_tiles.py -f /app/params.ini -p ${O2C_PROCESSES} -b "*${WEST}_${SOUTH}_${EAST}_${NORTH}"
