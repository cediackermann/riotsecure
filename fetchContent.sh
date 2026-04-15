#!/usr/bin/env bash

OUTPUT_DIR="content"
INPUT_FILE="${1:-urls.txt}"

mkdir -p "$OUTPUT_DIR"

# Validate input file

if [[ ! -f "$INPUT_FILE" ]]; then
echo "File not found: $INPUT_FILE"
exit 1
fi

download() {
url="$1"

name=$(echo "$url" | awk -F/ '{print $(NF-1)}')

filename="${name}.json"

echo "Fetching: $url -> $filename"

curl -sS "$url" -o "$OUTPUT_DIR/$filename"

echo "Saved: $filename"
}

export -f download
export OUTPUT_DIR

cat "$INPUT_FILE" | xargs -n 1 -P 5 bash -c 'download "$@"' _
