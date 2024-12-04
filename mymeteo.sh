#!/bin/bash

help(){
  echo "-c, --city <Your City> - Check weather for city"
  exit 0
}

for opt; do
    case "$opt" in
      -c | --city)
        city=$2 ;;
      -h | --help)
      help ;;
    esac
done

getLocation(){
  nominatim_res="https://nominatim.openstreetmap.org/search.php?q=$1&format=jsonv2";
  curl -sk ${nominatim_res} -o temp.json;

  lat=$( ./jq.exe '.[0].lat' temp.json);
  lon=$( ./jq.exe '.[0].lon' temp.json);

  rm temp.json

  echo "$lat $lon"
}

downloadStations(){
  stations="https://danepubliczne.imgw.pl/api/data/synop/"
  curl -sk ${stations} -o temp_stations.json
  size=$(./jq.exe 'length' temp_stations.json)

  echo "{" > temp_locations.json

  for ((i=0; i<size; i++))
  do
    check_city=$(./jq.exe ".[$i].stacja" temp_stations.json | tr -d '"')
    check_city=$(echo "$check_city" | sed 'y/ąćęłńóśźżĄĆĘŁŃÓŚŹŻ /acelnoszzACELNOSZZ_/')

    location=$(getLocation "$check_city")
    lat=$(echo "$location" | cut -d ' ' -f 1)
    lon=$(echo "$location" | cut -d ' ' -f 2)

    station_data="\"$check_city\": {\"lat\": $lat, \"lon\": $lon},"

    echo $station_data >> temp_locations.json;
  done

  echo "\"size\": $size, "\"lastupdate\"":\"$(date "+%Y-%m-%d")\" }" >> temp_locations.json
}


if [[ -e "temp_locations.json" ]]; then
  check_date=$(./jq.exe ".lastupdate" temp_locations.json | tr -d '"')
  if [[ "$check_date" != "$(date "+%Y-%m-%d")" ]]; then
    downloadStations
  fi
else
  downloadStations
fi
