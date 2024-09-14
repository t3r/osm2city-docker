
function tileToBounds {
  case "${1:0:1}" in
    'e')
      WEST="$((10#${1:1:3}))"
      ;;
    'w')
      WEST="-$((10#${1:1:3}))"
      ;;
  esac
  case "${1:4:1}" in
    's')
      SOUTH="-$((10#${1:5:2}))"
      ;;
    'n')
      SOUTH="$((10#${1:5:2}))"
      ;;
  esac
  EAST=$(($WEST+$2))
  NORTH=$(($SOUTH+$2))
}

function stgindexToBounds {

  local TILE=$1
  local X=$(( ($TILE >> 0) & 7 ))
  local Y=$(( ($TILE >> 3) & 7 ))
  local LAT=$(( (($TILE >> 6) & 255) - 90 ))
  local LON=$(( ($TILE >> 14) - 180 ))

  local L=${LAT#-} # abs()
  local TILE_WIDTH=0.125
  [[ $L -ge 22 ]] && TILE_WIDTH=0.25
  [[ $L -ge 62 ]] && TILE_WIDTH=0.5
  [[ $L -ge 76 ]] && TILE_WIDTH=1
  [[ $L -ge 83 ]] && TILE_WIDTH=2
  [[ $L -ge 86 ]] && TILE_WIDTH=4
  [[ $L -ge 89 ]] && TILE_WIDTH=12

  SOUTH=$( echo "$LAT + $Y * 0.125" | bc)
  NORTH=$( echo "$SOUTH + 0.125"|bc )
  WEST=$( echo "$LON + $X * $TILE_WIDTH" | bc )
  EAST=$( echo "$WEST + $TILE_WIDTH" | bc )
}

if [ "$ONE" ]; then
  REGEX='^[ew][01][0-9]{2}[ns][0-9]{2}$'
  if [[ "$ONE" =~ $REGEX ]]; then
    tileToBounds "$ONE" 1
  else
    echo "Invalid 1x1 parameter. Must be like w123n45." >&2
    exit 1
  fi
fi

if [ "$TEN" ]; then
  REGEX='[ew][01][0-9]0[ns][0-9]0'
  if [[ "$TEN" =~ $REGEX ]]; then
    tileToBounds "$TEN" 10
  else
    echo "Invalid 10x10 parameter. Must be like w120n40." >&2
    exit 1
  fi
fi

if [ "$TILE" ]; then
  stgindexToBounds "$TILE"
fi

if [ "$JSON" ]; then
  EAST=$(echo "$JSON" | jq -r '.east')
  WEST=$(echo "$JSON" | jq -r '.west')
  SOUTH=$(echo "$JSON" | jq -r '.south')
  NORTH=$(echo "$JSON" | jq -r '.north')
  DATABASE=$(echo "$JSON" | jq -r '.database')
fi

