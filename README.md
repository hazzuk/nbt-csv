# nbt-csv

A bash script to bulk export key NBT data from your old Minecraft world files.

Reads level.dat NBT data and some additional information via the file system. Then exporting the data read as a JSON file per each world. After which using the JSON data to create a combined CSV output file.

### CSV headers

- WorldFolderName
- LevelName
- LastPlayed
- WorldSize
- Players
- GameType
- RandomSeed
- Version

## Dependencies:

- [nbt-dump](https://github.com/extremeheat/nbt-dump) - CLI tool to read and write Minecraft named binary tag files
- [jq](https://github.com/jqlang/jq) - A lightweight and flexible command-line JSON processor

## Usage

- Install dependencies
- Download nbt-csv.bash and place it next to your worlds parent folder

```
nbt-csv.bash
worlds/
├─ world1/
│  ├─ level.dat
├─ world2/
│  ├─ level.dat
```

- Edit any of the user varibles displayed at the top of the script
- Run ./nbt-csv.bash

### Windows

To run on Windows either use the [Git Bash](https://git-scm.com/) command line provided with Git. Or run the script through the [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install).
