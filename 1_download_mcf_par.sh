#!/bin/bash

# establish connection
if [ -z "$JSESSIONID" ]; then
  read -p "Enter username: " USERNAME;
  read -s -p "Enter password: " PW;
  echo ""
  JSESSIONID=$(curl -s -k -u $USERNAME:$PW "https://db.humanconnectome.org/data/JSESSIONID")
  export JSESSIONID
fi
if [ -z "$(echo $JSESSIONID | grep -i 'error')" ]; then
  printf "\nConnected: %s\n\n" "$JSESSIONID"
else
  echo "Failed to connect to ConnectomeDB"
  unset JSESSIONID
  exit 1
fi

# get subjects
SUBJECTS=$(curl -s -k --cookie JSESSIONID=$JSESSIONID "https://db.humanconnectome.org/data/experiments?xsiType=xnat:mrSessionData&project=HCP_1200&columns=ID,label,URI&format=csv" | grep "_7T" | grep "experiments")
N=$(echo "$SUBJECTS" | wc -l)
I=0
for ROW1 in $SUBJECTS; do
  I=$((I + 1))
  SUB=$(echo $ROW1 | cut -d ',' -f 3)
  URI=$(echo $ROW1 | cut -d ',' -f 4)
  printf "%d/%d\t%s\t(%s)\n" "$I" "$N" "$SUB" "$URI"
  # get scans/collections
  COLLECTIONS=$(curl -s -k --cookie JSESSIONID=$JSESSIONID "https://db.humanconnectome.org${URI}/resources?columns=xnat_abstractresource_id,label&format=csv" | grep "_FIX")
  for ROW2 in $COLLECTIONS; do
    if [ -n "$(echo $ROW2 | grep _FIX)" ]; then
      # get files to download for each scan
      RESOURCE=$(echo $ROW2 | cut -d ',' -f 1)
      SCAN=$(echo $ROW2 | cut -d ',' -f 2)
      NAME=$(echo $SCAN | sed 's/_FIX//')
      FILES=$(curl -s -k --cookie JSESSIONID=$JSESSIONID "https://db.humanconnectome.org${URI}/resources/${RESOURCE}/files?columns=xnat_abstractresource_id,Name,URI&format=csv" | grep 'prefiltered_func_data_mcf.par')
      printf '\t%s\n' "$NAME"
      for ROW3 in $FILES; do
        FILEURI=$(echo $ROW3 | cut -d ',' -f 3)
        FILENAME=$(echo $FILEURI | awk -F '/' '{print $(NF-3)}')_$(echo $ROW3 | cut -d ',' -f 1)
        mkdir -p $SUB
        printf '\t\t%s\n\t\t' "$FILENAME"
        curl --cookie JSESSIONID=$JSESSIONID -k -s -o $SUB/$FILENAME  "https://db.humanconnectome.org$FILEURI"
        printf '\n'
      done
    fi
  done
done
