#!/bin/sh

# declare folders to skip

for folder in */; do
    if [ -f "$folder/pyproject.toml" ]; then
        echo "Creating requirements for $folder"
        cd $folder
        poetry export -f requirements.txt --output requirements.txt

        # if folder == translator/
        # in requirements.txt, replace substring home/fco/TFG-Fast-Diagnosis-System/translator with app
        if [ "$folder" = "translator/" ]; then
            echo "Replacing path in requirements.txt"
            sed -i 's/home\/fco\/TFG-Fast-Diagnosis-System\/translator/app/g' requirements.txt
        fi


        cd ..
    fi
done