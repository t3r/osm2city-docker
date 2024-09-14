#!/bin/bash
set -euxo pipefail

INPUT=
WEST=
EAST=
SOUTH=
NORTH=
DATABASE=
JSON=
DBCREATED=
EXTRACTPADDING="${EXTRACTPADDING:-0.1}"
TEN=
ONE=
TILE=

TMPDIR="$(mktemp -d)"

function cleanup {
  if [ ! -z "$TMPDIR" -a -d "$TMPDIR" ]; then
    echo "cleaning up $TMPDIR"
    rm -rf "$TMPDIR"
  fi

#  to drop db or not to drop?
#  if [ "$DBCREATED" -eq "Yes" ]; then
#    echo "dropping database $DATABASE"
#    psql -c "drop database $DATABASE" || true;
#  fi
  true
}


function checkRange {
#  if [ "$1" -lt "$2" -o "$1" -gt "$3" ]; then
#    echo "$4 is $1 but must be between $2 and $3" 1>&2;
#    exit false
#  fi
  true
}

trap cleanup EXIT

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
    '--json')    set -- "$@" '-j'   ;;
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
    'e') EAST=$OPTARG ;;
    'w') WEST=$OPTARG ;;
    's') SOUTH=$OPTARG ;;
    'n') NORTH=$OPTARG ;;
    'i') INPUT=$OPTARG ;;
    'd') DATABASE=$OPTARG ;;
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

BBOX="$WEST,$SOUTH,$EAST,$NORTH"
if [ "$BBOX" != ",,," ]; then
  test -z "$EAST" && EAST=0
  test -z "$WEST" && WEST=0
  test -z "$SOUTH" && SOUTH=0
  test -z "$NORTH" && NORTH=0
  BBOX="$WEST,$SOUTH,$EAST,$NORTH"
else
  BBOX=""
fi

if [ -z "$INPUT" -o ! -r "$INPUT" -o ! -f "$INPUT" ]; then
  echo "INPUT not readable." 1>&2;
  exit 1
fi

JOBID=$(cat /proc/sys/kernel/random/uuid)
echo "Job ID is $JOBID"
mkdir -p "$TMPDIR/$JOBID"

#JAVACMD_OPTIONS="-Xmx24G -Djava.io.tmpdir=/app/tmp -server"
export JAVACMD_OPTIONS="${JAVACMD_OPTIONS:--server}"

PBF="$INPUT"

if [ -n "$BBOX" ]; then
  XWEST=$(echo "$WEST-$EXTRACTPADDING"|bc)
  XEAST=$(echo "$EAST+$EXTRACTPADDING"|bc)
  XSOUTH=$(echo "$SOUTH-$EXTRACTPADDING"|bc)
  XNORTH=$(echo "$NORTH+$EXTRACTPADDING"|bc)
  PBF="$TMPDIR/$JOBID.osm.pbf"
  osmium extract \
    --bbox "$XWEST,$XSOUTH,$XEAST,$XNORTH" \
    --overwrite \
    --output "$PBF" \
    "$INPUT"
  INPUT="$PBF"
fi

NODELOCATIONSTORE="${NODELOCATIONSTORE:-TempFile}"   # InMemory

osmosis --read-pbf "$INPUT" \
        --log-progress \
        --write-pgsql-dump enableBboxBuilder=yes enableLinestringBuilder=no keepInvalidWays=no directory="$TMPDIR/$JOBID" nodeLocationStoreType="$NODELOCATIONSTORE"

test -z "$DATABASE" && DATABASE=osm_$(echo $JOBID|sed 's/-/_/g')
export PAGER=cat

pushd "$TMPDIR/$JOBID"
if psql -lqt | cut -d \| -f 1 | grep -qw "$DATABASE"; then
  echo "database $DATABASE exists, reusing it."
  DBCREATED=
else
  echo "creating database $DATABASE."
  psql -c "create database $DATABASE";
  DBCREATED=Yes
fi
psql -d "$DATABASE" \
  -c 'create extension if not exists postgis;' \
  -c 'create extension if not exists hstore;' \
  -f /usr/share/doc/osmosis/examples/pgsnapshot_schema_0.6.sql \
  -f /usr/share/doc/osmosis/examples/pgsnapshot_schema_0.6_bbox.sql \
  -c 'create index on nodes USING gin(tags) WHERE tags is not null;' \
  -c 'create index on ways USING gin(tags) WHERE tags is not null' \
  -c 'create index on relations USING gin(tags) WHERE tags is not null;' \
  -f /usr/share/doc/osmosis/examples/pgsnapshot_load_0.6.sql
popd
