#!/bin/sh

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <input_binary_filename>"
  exit 1
fi

# Get the binary filename from the argument
BINARY_FILE="$1"

# Define output filenames based on the input binary
SIGNED_FILE="${BINARY_FILE%.bin}_signed_espsecure.bin"

# Define signing key filenames
SIGNING_KEY="${BINARY_FILE%.bin}_signing_key.pem"

echo Running script to sign image locally

espsecure.py generate_signing_key --version 2 "$SIGNING_KEY" 
espsecure.py sign_data  --version 2 --keyfile "$SIGNING_KEY" -o "$SIGNED_FILE" "$BINARY_FILE"
