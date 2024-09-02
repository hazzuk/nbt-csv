#!/bin/bash

# Copyright (c) 2024 hazzuk. All rights reserved.
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


#  _____ _____ _____    _____ _____ _____ 
# |   | | __  |_   _|__|     |   __|  |  |
# | | | | __ -| | ||___|   --|__   |  |  |
# |_|___|_____| |_|    |_____|_____|\___/ 
#
# Script to bulk export NBT data from Minecraft worlds into a CSV file
# https://github.com/hazzuk/nbt-csv

# Dependencies:
# nbt-dump (CLI tool to read and write Minecraft named binary tag files)    https://github.com/extremeheat/nbt-dump
# jq (a lightweight and flexible command-line JSON processor)               https://github.com/jqlang/jq


# User-defined variables
PARENT_DIR="worlds"             # Parent folder where the worlds are stored
JQ_EXE="C:/path/to/jq.exe"      # Path to the jq executable, set "" if jq is in the PATH
OUTPUT_FILE="nbt.csv"           # Name of the output CSV file
NBTDUMP_VERBOSE=false           # Set to true to see verbose output from nbt-dump

# Change directory to the parent folder where the worlds are stored
cd "$PARENT_DIR" || exit 1

echo ""
echo -e "\e[1;34m(1) Exporting NBT data from '$PARENT_DIR' directory\e[0m"

# Loop through each subfolder in the directory
for world_dir in */; do
    # Remove trailing slash from world folder name
    world_name="${world_dir%/}"

    # Check if the level.dat file exists in the subfolder
    if [ -f "$world_dir/level.dat" ]; then
        # Run nbt-dump command, generating a JSON file with the name of the subfolder
        echo "Exporting '$world_name'"
        if [ "$NBTDUMP_VERBOSE" = true ]; then
            nbt-dump "$world_dir/level.dat" "$world_name.json"
        else
            nbt-dump "$world_dir/level.dat" "$world_name.json" > /dev/null
        fi

        # JSON file created, now add additional information

        # Calculate the size of the world folder in MB
        world_size=$(du -sh "$world_dir" | cut -f1)

        # Initialize the players array
        players=()

        # Check if the players folder exists
        if [ -d "$world_dir/players" ]; then
            # Loop through player files and remove the .dat extension
            for player_file in "$world_dir/players"/*.dat; do
                # Only add the player if the file actually exists (handles cases with no players)
                [ -e "$player_file" ] && players+=("$(basename "$player_file" .dat)")
            done
        fi

        # Convert the players array to a JSON array
        players_json=$(printf ',"%s"' "${players[@]}")
        players_json="[${players_json:1}]"

        # Add additional information to the JSON file
        if [ "$JQ_EXE" == "" ]; then
            jq ". + {\"WorldSize\": \"$world_size\", \"Players\": $players_json}" "$world_name.json" > tmp.json && mv tmp.json "$world_name.json"
        else
            $JQ_EXE ". + {\"WorldSize\": \"$world_size\", \"Players\": $players_json}" "$world_name.json" > tmp.json && mv tmp.json "$world_name.json"
        fi

    else
        echo "Warn, no level.dat found in $world_name"
    fi
done

echo ""
echo -e "\e[1;34m(2) Creating combined CSV file\e[0m"

# Create the header for the CSV
echo "WorldFolderName,LevelName,LastPlayed,WorldSize,Players,GameType,RandomSeed,version" > $OUTPUT_FILE

# Function to combine 32-bit integers to 64-bit
combine_64bit() {
    high=$1
    low=$2
    # Treat low as an unsigned integer
    echo $(( (high * 4294967296 ) | (low & 0xFFFFFFFF) ))
}

# Function to convert Unix epoch (in milliseconds) to human-readable date and time
convert_epoch_to_datetime() {
    epoch_ms=$1
    # Convert milliseconds to seconds
    epoch=$((epoch_ms / 1000))
    # Convert epoch to date and time format (e.g., "YYYY-MM-DD HH:MM:SS")
    date -d @"$epoch" +"%Y-%m-%d %H:%M:%S"
}

# Iterate through all JSON files in the parent folder
for json_file in *.json; do
    # Check if the file exists
    if [[ ! -f "$json_file" ]]; then
        continue
    fi

    echo "Processing '$json_file'"

    # World folder name (remove .json extension)
    WorldFolderName="${json_file%.json}"

    # Level name
    LevelName=$($JQ_EXE -r '.value.Data.value.LevelName.value' "$json_file")

    # Last played
    LastPlayed_high=$($JQ_EXE -r '.value.Data.value.LastPlayed.value[0]' "$json_file")
    LastPlayed_low=$($JQ_EXE -r '.value.Data.value.LastPlayed.value[1]' "$json_file")
    LastPlayed_epoch=$(combine_64bit $LastPlayed_high $LastPlayed_low)
    LastPlayed=$(convert_epoch_to_datetime $LastPlayed_epoch)

    # World size
    WorldSize=$($JQ_EXE -r '.WorldSize' "$json_file")

    # Players
    Players=$($JQ_EXE -r '.Players[]' "$json_file" | paste -sd ";" -)

    # Game type
    GameTypeValue=$($JQ_EXE -r '.value.Data.value.GameType.value' "$json_file")
    if [[ "$GameTypeValue" -eq 0 ]]; then
        GameType="Survival"
    elif [[ "$GameTypeValue" -eq 1 ]]; then
        GameType="Creative"
    else
        GameType="$GameTypeValue"
    fi

    # Random seed
    RandomSeed_high=$($JQ_EXE -r '.value.Data.value.RandomSeed.value[0]' "$json_file")
    RandomSeed_low=$($JQ_EXE -r '.value.Data.value.RandomSeed.value[1]' "$json_file")
    RandomSeed=$(combine_64bit $RandomSeed_high $RandomSeed_low)

    # Version
    version=$($JQ_EXE -r '.value.Data.value.version.value' "$json_file")

    # Write extracted data as row in CSV file
    echo "$WorldFolderName,$LevelName,$LastPlayed,$WorldSize,\"$Players\",$GameType,$RandomSeed,$version" >> $OUTPUT_FILE

    # Delete the JSON file after processing
    rm "$json_file"
done

mv $OUTPUT_FILE ../

echo ""
echo -e "\e[1;34mAll worlds data processed into '$OUTPUT_FILE'\e[0m"
read -p "Press [Enter] to continue..."
