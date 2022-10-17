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
  printf "%d/%d\t%s\t(%s)" "$I" "$N" "$SUB" "$URI"
  if [ -d "$SUB" ]; then
    printf "\tSKIPPED\n"
  else
    printf "\n"
    # get scans/collections
    COLLECTIONS=$(curl -s -k --cookie JSESSIONID=$JSESSIONID "https://db.humanconnectome.org${URI}/resources?columns=xnat_abstractresource_id,label&format=csv" | grep "_FIX" | grep -v "_RET")
    for ROW2 in $COLLECTIONS; do
      if [ -n "$(echo $ROW2 | grep _FIX)" ]; then
        # get files to download for each scan
        RESOURCE=$(echo $ROW2 | cut -d ',' -f 1)
        SCAN=$(echo $ROW2 | cut -d ',' -f 2)
        NAME=$(echo $SCAN | sed 's/_FIX//')
        FILES=$(curl -s -k --cookie JSESSIONID=$JSESSIONID "https://db.humanconnectome.org${URI}/resources/${RESOURCE}/files?columns=xnat_abstractresource_id,Name,URI&format=csv" | grep '_Atlas_hp2000_clean.dtseries.nii')
        printf '\t%s\n' "$NAME"
        for ROW3 in $FILES; do
          FILENAME=$(echo $ROW3 | cut -d ',' -f 1)
          FILEURI=$(echo $ROW3 | cut -d ',' -f 3)
          mkdir -p $SUB
          printf '\t\t%s\n\t\t' "$FILENAME"
          curl --cookie JSESSIONID=$JSESSIONID -k -s -o $SUB/$FILENAME  "https://db.humanconnectome.org$FILEURI"
          printf '\n'
        done
      fi
    done
  fi
done
