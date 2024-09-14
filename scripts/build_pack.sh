#!/bin/bash
set -euo pipefail

$(dirname $0)/build.sh $*
$(dirname $0)/pack.sh "$OSM2CITY_PATH_TO_OUTPUT" "$OSM2CITY_PATH_TO_PACKED"
$(dirname $0)/dirindex.sh "$OSM2CITY_PATH_TO_PACKED"
