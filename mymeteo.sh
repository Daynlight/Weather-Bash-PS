#!/bin/bash

checkIfNeedToDownloadData(){
    if [[ -e "~/.cache/mymeteo/temp_locations.json" ]]; then
    size=$(./jq.exe 'length' ~/.cache/mymeteo/temp_locations.json)
    check_date=$(./jq.exe '.[0].lastupdate' ~/.cache/mymeteo/temp_locations.json | tr -d '"')
    if [[ "$check_date" != "$(date "+%Y-%m-%d %H")" ]]; then
      downloadData
    fi
  else
    downloadData
  fi
}

downloadData(){
  stations="https://danepubliczne.imgw.pl/api/data/synop/"
  curl -sk ${stations} -o ~/.cache/mymeteo/temp_locations_stations.json
  size=$(./jq.exe 'length' ~/.cache/mymeteo/temp_locations_stations.json)

  if [[ ! -f ~/.cache/mymeteo/temp_locations.json ]]; then
    echo "[{\"lastupdate\":\"$(date "+%Y-%m-%d %H")\"}]" > ~//.cache/mymeteo/temp_locations.json
  fi
 
  for ((i=0; i<size; i++))
  do
    check_city=$(./jq.exe ".[$i].stacja" ~//.cache/mymeteo/temp_locations_stations.json | tr -d '"')
    check_city=$(echo "$check_city" | sed 'y/ąćęłńóśźżĄĆĘŁŃÓŚŹŻ /acelnoszzACELNOSZZ_/')
    check_city=$(echo "$check_city" | tr '[:upper:]' '[:lower:]')
    checkEntries "$check_city" "0" > /dev/null 2>&1
  done
}

checkEntries(){
  find=0
  res=$(searchForEntry "$1")
  if [[ -n $res ]]; then
    find=1
    if (( $2 == 1 )); then
      echo $res
    fi
  fi
  if (( find == 0 )); then
    addEntry "$1"
  fi
}

addEntry(){
  sleep 1s
  nominatim_res="https://nominatim.openstreetmap.org/search.php?city=$1&country=Poland&format=jsonv2";
  curl -sk ${nominatim_res} -o ~/.cache/mymeteo/temp.json;

  lat=$( ./jq.exe '.[0].lat' ~/.cache/mymeteo/temp.json);
  lon=$( ./jq.exe '.[0].lon' ~/.cache/mymeteo/temp.json);
  new_location="{\"name\":\"$1\", \"lat\":$lat, \"lon\":$lon}"
  ./jq.exe ". += [$new_location]" ~/.cache/mymeteo/temp_locations.json > ~/.cache/mymeteo/temp_locations_new.json && mv ~/.cache/mymeteo/temp_locations_new.json ~/.cache/mymeteo/temp_locations.json
  
  rm ~/.cache/mymeteo/temp.json

  echo "$lat $lon"
}

searchForEntry(){
  size=$(./jq.exe 'length' ~/.cache/mymeteo/temp_locations.json)
  for ((i=0; i<size; i++))
  do
    name=$(./jq.exe ".[$i].name" ~/.cache/mymeteo/temp_locations.json | tr -d '"')
    if [[ "$name" == "$1" ]]; then
      find=1
      lat=$( ./jq.exe ".[$i].lat" ~/.cache/mymeteo/temp_locations.json);
      lon=$( ./jq.exe ".[$i].lon" ~/.cache/mymeteo/temp_locations.json);
      echo "$lat $lon"
      break
    fi
  done
}

findNearest(){
  size=$(./jq.exe 'length' ~/.cache/mymeteo/temp_locations_stations.json)
  min=1
  for ((i=2; i<size+1; i++))
  do
    min_lat=$(./jq.exe ".[$min].lat" ~/.cache/mymeteo/temp_locations.json | tr -d '"')
    min_lon=$(./jq.exe ".[$min].lon" ~/.cache/mymeteo/temp_locations.json | tr -d '"')
    lat=$(./jq.exe ".[$i].lat" ~/.cache/mymeteo/temp_locations.json | tr -d '"')
    lon=$(./jq.exe ".[$i].lon" ~/.cache/mymeteo/temp_locations.json | tr -d '"')
    distance=$(awk '{print ($3-$1)*($3-$1) + ($4-$2)*($4-$2)}' <<< "$1 $2 $lat $lon")
    min_distance=$(awk '{print ($3-$1)*($3-$1) + ($4-$2)*($4-$2)}' <<< "$1 $2 $min_lat $min_lon")
    if (( $(awk '{print ($1 < $2)}' <<< "$distance $min_distance") )); then
      min=$i
    fi
  done

  echo $min
}

printUI(){
  min=$1-1
  id_stacji=$(./jq.exe ".[$min].id_stacji" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')
  stacja=$(./jq.exe ".[$min].stacja" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')
  temperatura=$(./jq.exe ".[$min].temperatura" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')
  predkosc_wiatru=$(./jq.exe ".[$min].predkosc_wiatru" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')
  kierunek_wiatru=$(./jq.exe ".[$min].kierunek_wiatru" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')
  wilgotnosc_wzgledna=$(./jq.exe ".[$min].wilgotnosc_wzgledna" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')\
  suma_opadu=$(./jq.exe ".[$min].suma_opadu" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')
  cisnienie=$(./jq.exe ".[$min].cisnienie" ~/.cache/mymeteo/temp_locations_stations.json | tr -d '"')

  echo "$stacja [$id_stacji] / $(date +"%Y-%m-%d %H:%M")"
  echo ""
  echo "temperatura: $temperatura °C"
  echo "predkosc wiatru: $predkosc_wiatru m/s"
  echo "kierunek wiatru: $kierunek_wiatru °"
  echo "wilgotnosc wzgledna: $wilgotnosc_wzgledna %"
  echo "suma opadu: $suma_opadu mm"
  echo "cisnienie: $cisnienie hPa"
}

main(){
  mkdir -p ~/.cache/mymeteo/
  checkIfNeedToDownloadData
  
  check_city=$1
  check_city=$(echo "$check_city" | sed 'y/ąćęłńóśźżĄĆĘŁŃÓŚŹŻ /acelnoszzACELNOSZZ_/')
  check_city=$(echo "$check_city" | tr '[:upper:]' '[:lower:]')
  city_location=$(checkEntries "$check_city" "1")
  city_lat=$(echo "$city_location" | cut -d ' ' -f 1 | xargs | awk '{print $1}')
  city_lon=$(echo "$city_location" | cut -d ' ' -f 2 | xargs | awk '{print $1}')

  printUI $(findNearest "$city_lat" "$city_lon")

}


help(){
  echo "-c, --city <Your City> - Check weather for city"
  echo "Author: Daniel Stodulski"
  exit 0
}

for opt; do
    case "$opt" in
      -c | --city)
        main "$2" ;;
      -h | --help)
      help ;;
    esac
done