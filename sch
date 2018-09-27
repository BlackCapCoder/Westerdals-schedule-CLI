#!/bin/zsh

url="https://cloud.timeedit.net/campuskristiania_test3/web/oslo/ri633QQQ135Zn6Q53Y64Q7Z9y5Z07.ics"
pth_cache=~/.cache/schedule
upd_freq=$(( 60*60 ))


download () {
  curl -s "$url" \
    | sed -n 's/LOCATION:Rom:\s/LOCATION:/g;/BEGIN:VEVENT/,/END:VEVENT/{s/BEGIN:VEVENT/\{/;s/END:VEVENT/\}/;p};' \
    | grep -E "[{}]|DTSTART|DTEND|LOCATION" \
    | sed 's/\(\w*\):\([ a-zA-Z0-9]*\)/"\1": "\2" ,/g' \
    | tr -d '\r\n' \
    | sed 's/,}/}/g' \
    | jq -cr '.' \
    | jq -s --compact-output 'sort_by(.DTSTART) | .[]'
}

getSchedule () {
  if [ -f $pth_cache ]; then
    now=$(date +%s)
    modified=$(date -r $pth_cache +%s)
    if [ $(( $now - $modified )) -lt $upd_freq ]; then
      cat $pth_cache
      return
    fi
  fi

  (>&2 echo "[INFO] Downloading schedule")
  data=$(download)

  if [ ! -z $data ]; then
    echo "$data" > "$pth_cache"
    echo "$data"
  else
    (>&2 echo "[WARNING] Failed to update schedule, using cache")
    if [ -f $pth_cache ]; then
      cat $pth_cache
    else
      (>&2 echo "[ERROR] No cache!")
      exit 1
    fi
  fi
}

# 20181003T141500Z
parseDate () {
  inp=$1
  echo "${inp:0:4}/${inp:4:2}/${inp:6:2} $(( ${inp:9:2} + 2 )):${inp:11:2}:${inp:13:2}"
}


# Check dependencies
hash jq   2>/dev/null || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
hash ansi 2>/dev/null || {
  echo >&2 "[INFO] Install ansi for pretty colors: https://github.com/fidian/ansi";
}

# Aquire schedule
data=$(getSchedule)

if [ $? -ne 0 ]; then
  exit 1
fi

# Table header
if hash ansi 2>/dev/null; then
  ansi --bg-green --bold "Date   Start  End    Room"
else
  echo "Date   Start  End    Room"
fi

today=$(date -d $(date '+%Y/%m/%d') +%s)

while read -r line; do
  dts=$(parseDate $(echo $line | jq -r '.DTSTART'))
  dte=$(parseDate $(echo $line | jq -r '.DTEND'))
  str="$(date -d "$dts" "+%m/%d")  $(date -d "$dts" "+%H:%M")  $(date -d "$dte" "+%H:%M")  $(echo $line | jq -r '.LOCATION' | awk '{print $2}' | tr -d '\n')"

  if [ $(date -d $(date -d "$dts" '+%Y/%m/%d') +%s) -eq $today ]; then
    if hash ansi 2>/dev/null; then
      ansi --bold --yellow -n "$str"
    else
      echo -n "$str"
    fi

    t=$(( $(date -d "$dts" +%s) - $(date +%s) ))

    if hash ansi 2>/dev/null; then
      ansi --red -n " <- TODAY"
    else
      echo -n " <- TODAY"
    fi

    if [ $(date -d $dts +%s) -gt $(date +%s) ]; then
      if hash ansi 2>/dev/null; then
        ansi --red -n ", T-$(date -ud "@$t" +%T)"
      else
        echo -n ", T-$(date -ud "@$t" +%T)"
      fi
    fi

    echo
  else
    echo "$str"
  fi
done <<< $(echo $data)
