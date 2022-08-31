#!/bin/sh

for folder in */; do
    if [ -f "$folder/pyproject.toml" ]; then
        echo "Creating requirements for $folder"
        cd $folder
        poetry export -f requirements.txt --output requirements.txt
        cd ..
    fi
done