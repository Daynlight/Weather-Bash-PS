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

nominatim_res="https://nominatim.openstreetmap.org/search.php?q=$city&format=jsonv2"
curl -sk ${nominatim_res} -o temp_json.json

lat=$( ./jq.exe '.[0].lat' temp_json.json)
lon=$( ./jq.exe '.[0].lon' temp_json.json)

echo ${lat} ${lon}

rm temp_json.json