#!/usr/bin/env bash

# Default values
color="0,85,0"
output_file=""
padding=5
type="box"  # Default type is "box"

# Usage function
usage() {
    echo "Usage: $0 -c <RGB_color> -i <input_file> [-o <output_file>] [-p <padding>] [-t <type>]"
    echo "Options:"
    echo "  -c <RGB_color>: specify the RGB color (format: R,G,B)"
    echo "  -i <input_file>: specify the input image file"
    echo "  -o <output_file>: specify the output image file (optional)"
    echo "  -p <padding>: specify the padding value (default: 5)"
    echo "  -t <type>: specify the type ('box' or 'crop', default: 'box')"
    exit 1
}

# Parse options
while getopts "c:i:o:p:t:" opt; do
    case $opt in
        c)
            color=$OPTARG
            ;;
        i)
            input_file=$OPTARG
            ;;
        o)
            output_file=$OPTARG
            ;;
        p)
            padding=$OPTARG
            ;;
        t)
            type=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Check if required options are provided
if [ -z "$color" ] || [ -z "$input_file" ]; then
    echo "Missing required options." >&2
    usage
fi

# If output file is not provided, set default output file name
if [ -z "$output_file" ]; then
    input_dir=$(dirname "$input_file")
    output_file="$input_dir/output_image.png"
fi

# Create a temporary text file
temp_textfile=$(mktemp "$(dirname "$input_file")/temp_file.XXXXXX.txt")

# Convert the image to a text file
convert "$input_file" txt:- > "$temp_textfile"

# Find all coordinates of the specified color
coordinates=$(grep "srgb($color)" "$temp_textfile" | cut -d ':' -f 1)

# Find the minimum and maximum x and y coordinates
min_x=$(echo "$coordinates" | cut -d ',' -f 1 | sort -n | head -n 1)
max_x=$(echo "$coordinates" | cut -d ',' -f 1 | sort -n | tail -n 1)
min_y=$(echo "$coordinates" | cut -d ',' -f 2 | sort -n | head -n 1)
max_y=$(echo "$coordinates" | cut -d ',' -f 2 | sort -n | tail -n 1)

# Add padding to the minimum and maximum x and y coordinates
min_x=$((min_x - padding))
max_x=$((max_x + padding))
min_y=$((min_y - padding))
max_y=$((max_y + padding))

echo "min x $min_x" 
echo "max x $max_x"
echo "min y $min_y"
echo "max y $max_y"


if [ "$type" == "crop" ]; then
    echo "Crop"
    temp_file=$(mktemp "$(dirname "$input_file")/temp.XXXXXX.png")
    convert -size $(identify -format "%wx%h" "$input_file") xc:black -fill "white" \
        -draw "rectangle $min_x,$min_y $max_x,$max_y" png:- > "$temp_file"
    convert "$input_file" "$temp_file" -alpha off -compose copy_opacity \
        -composite -trim +repage -geometry x$(identify -format "%h" "$temp_file") "$output_file"
    # remove temp file
    rm "$temp_file"
else
    echo "Box"
    # Draw bounding box around all the identified coordinates
    convert "$input_file" -fill none -stroke white -strokewidth 3 \
        -draw "stroke-dasharray 10 10 rectangle $min_x,$min_y $max_x,$max_y" "$output_file"
fi

# Remove the temporary text file
rm "$temp_textfile"
