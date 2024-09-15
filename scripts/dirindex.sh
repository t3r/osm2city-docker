#!/bin/bash
set -euxo pipefail

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

do_header() {
cat << EOF
#FlightGear scenery directory index created on $(date), Build-ID ${2:-none}
#scenery data based on openstreetmap data
#see https://github.com/t3r/cloudcity for details, license and copyright
version:1
path:${1:-}
EOF
}

do_sha1sum() {
  sha1sum $1|cut -f1 -d' '
}

# create (if needed) .dirindex in current directory.
# return the sha1sum of the .dirindex
do_the_dirindex() {
  if [ -f .dirindex ] && [ -z "$(find . -type f -newer .dirindex)" ]; then
    # we have a .dirindex and there are no newer files. Assume, .dirindex is up-to-date
    do_sha1sum .dirindex
    return
  fi
  # looks like we need to create a new .dirindex
  local DIRINDEX="$(do_header ${1:-})"

  # start with sorted subdirs fist
  for dir in $(ls -1d */ 2>/dev/null); do
    test -z "$dir" && continue
    dir=$(basename $dir)
    pushd $dir
    THEPATH="${1:-}"
    test ! -z "$THEPATH" && THEPATH+="/"
    THEPATH+=$dir
    SUBDIRSHA1="$(do_the_dirindex $THEPATH)"
    printf -v DIRINDEX '%s\nd:%s:%s' "$DIRINDEX" "$(basename $dir)" "$SUBDIRSHA1"
    popd
  done

  for f in $(find .  -maxdepth 1 -type f -name '*.txz'|sort -f); do
    st_size="$(stat -c %s $f)"
    printf -v DIRINDEX '%s\nt:%s:%s:%d' "$DIRINDEX" "$(basename $f)" "$(do_sha1sum $f)" "$st_size"
  done

  echo "$DIRINDEX" > .dirindex
  do_sha1sum .dirindex
}


pushd "$(readlink -f ${1:-.})"
do_the_dirindex
popd
