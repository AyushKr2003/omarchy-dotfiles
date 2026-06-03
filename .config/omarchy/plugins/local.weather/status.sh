#!/bin/bash

location=${1:-}
if [[ -n $location ]]; then
  location="/${location}"
fi

weather_data=$(curl -fsS --max-time 3 "https://wttr.in${location}?format=j1" 2>/dev/null | jq -er '[.current_condition[0].weatherCode, .weather[0].astronomy[0].sunrise, .weather[0].astronomy[0].sunset] | select(all(. != null and . != "")) | @tsv' 2>/dev/null) || weather_data=

if [[ -n $weather_data ]]; then
  IFS=$'\t' read -r weather_code sunrise sunset <<< "$weather_data"
  now_epoch=$(date +%s)
  sunrise_epoch=$(date -d "today $sunrise" +%s 2>/dev/null || echo 0)
  sunset_epoch=$(date -d "today $sunset" +%s 2>/dev/null || echo 0)

  if (( sunrise_epoch > 0 && sunset_epoch > 0 && (now_epoch < sunrise_epoch || now_epoch >= sunset_epoch) )); then
    night=true
  else
    night=false
  fi

  case $weather_code in
    113) [[ $night == "true" ]] && icon="" || icon="" ;;
    116) [[ $night == "true" ]] && icon="" || icon="" ;;
    119|122) icon="" ;;
    143|248|260) icon="" ;;
    176|263|353) [[ $night == "true" ]] && icon="" || icon="" ;;
    179|227|230|323|326|368) [[ $night == "true" ]] && icon="" || icon="" ;;
    182|185|281|284|311|314|317|320|350|362|365|374|377) icon="" ;;
    200|386|389|392|395) icon="" ;;
    266|293|296|299|302|305|308|356|359) icon="" ;;
    329|332|335|338|371) icon="" ;;
    *) icon="" ;;
  esac
fi

if [[ -n $icon ]]; then
  icon=$(printf '%s' "$icon" | sed 's/["\\]/\\&/g')
  printf '{"text":"%s"}\n' "$icon"
else
  printf '{"text":"","class":"unavailable"}\n'
fi
