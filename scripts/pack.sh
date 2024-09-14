#!/bin/bash
set -euo pipefail

if [ $# != 2 ]; then
  SOURCE="$OSM2CITY_PATH_TO_OUTPUT"
  TARGET="$OSM2CITY_PATH_TO_PACKED"
  if [ -z "$SOURCE" -o -z "$TARGET" ]; then
    echo "usage: $0 sourcedir targetdir"
    exit 1
  fi
else
  SOURCE="$1"
  TARGET="$2"
fi

SOURCE=$(readlink -f "$SOURCE")

mkdir -p "$TARGET"
TARGET=$(readlink -f "$TARGET")


if [ ! -d $SOURCE ]; then
  echo "$SOURCE does not exist, exiting."
  exit 1
fi

pushd $SOURCE  > /dev/null
  ( for d in $(ls -d Buildings Details Pylons Roads Trees 2>/dev/null); do
    pushd $d  > /dev/null
    for tenten in $(ls -d [ew][01][0-9]0[ns][0-9]0/ 2>/dev/null); do
      pushd $tenten  > /dev/null
      mkdir -p "${TARGET}/${d}/${tenten}"
      for oneone in $(ls -d [ew][01][0-9][0-9][ns][0-9][0-9]/ 2>/dev/null); do
        TXZ="${TARGET}/${d}/$(basename ${tenten})/$(basename ${oneone}).txz"
        if [ ! -d $oneone ]; then
          continue
        fi
        if [ ! -f "$TXZ" ] || [ ! -z "$(find $oneone -type f -newer $TXZ)" ]; then
          echo "$(pwd),$TXZ,$oneone"
        fi
      done
      popd > /dev/null
    done
    popd > /dev/null
  done )| parallel -C ',' tar  --verbose --directory {1} --create --xz --file {2} {3}
popd > /dev/null

#Remove stale archives
echo "Cleanup $TARGET"
pushd $TARGET 2> /dev/null
pwd
  find . -name '*.txz' | while read f; do
    if [ ! -d "$SOURCE/$(dirname $f)/$(basename $f .txz)" ]; then
      echo "removing stale  $f"
      rm -f "$f"
    fi
  done
popd

echo "Doing the dirindex on $TARGET"
$(dirname $0)/dirindex.sh "$TARGET"
