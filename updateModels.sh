#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <folder>"
  exit 1
fi

FOLDER="$1"

for modelfile in "$FOLDER"/Modelfile.*; do
  [ -f "$modelfile" ] || continue
  name="${modelfile##*.}"
  ollama create "$name" -f "$modelfile"
done