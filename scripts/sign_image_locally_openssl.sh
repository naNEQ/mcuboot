#!/bin/sh

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <input_binary_filename>"
  exit 1
fi

# Get the binary filename from the argument
BINARY_FILE="$1"

# Define output filenames based on the input binary
DIGEST_FILE="${BINARY_FILE%.bin}_digest.bin"
SIGNED_FILE="${BINARY_FILE%.bin}_signed_openssl.bin"

# Define signing key filenames
SIGNING_KEY="${BINARY_FILE%.bin}_signing_key.pem"
PUBLIC_KEY="${BINARY_FILE%.bin}_public_key.pem"

# Define output signature filename
SIGNATURE_FILE="${BINARY_FILE%.bin}_signature_openssl.bin"

echo ------------------------
echo Running script to sign image locally using openssl
echo ------------------------

echo ""
echo ------------------------
echo Generating digest of the image binary file
echo ------------------------
openssl dgst -sha256 -binary "$BINARY_FILE"  > "$DIGEST_FILE"

echo ""
echo ------------------------
echo Generating signing key
echo ------------------------
espsecure.py generate_signing_key --version 2 "$SIGNING_KEY"

echo ""
echo ------------------------
echo Generating an RSA-PSS signature
echo ------------------------
openssl pkeyutl -sign \
    -in  "$DIGEST_FILE" \
    -inkey "$SIGNING_KEY" \
    -out "$SIGNATURE_FILE" \
    -pkeyopt digest:sha256 \
    -pkeyopt rsa_padding_mode:pss \
    -pkeyopt rsa_pss_saltlen:32

espsecure.py extract_public_key -v 2 -k "$SIGNING_KEY" "$PUBLIC_KEY"

echo ""
echo ------------------------
echo Verifying the generated signature
echo ------------------------
openssl pkeyutl -verify \
    -in "$DIGEST_FILE" \
    -pubin -inkey "$PUBLIC_KEY" \
    -sigfile "$SIGNATURE_FILE" \
    -pkeyopt rsa_padding_mode:pss \
    -pkeyopt rsa_pss_saltlen:32 \
    -pkeyopt digest:sha256

echo ""
echo ------------------------
echo Sign the image
echo ------------------------
espsecure.py sign_data -v 2 --pub-key "$PUBLIC_KEY" --signature "$SIGNATURE_FILE" --output "$SIGNED_FILE" "$BINARY_FILE"

echo ""
echo ------------------------
echo Verifying the signed image
echo ------------------------

# Check if the signature file was created
if [ ! -f "$SIGNED_FILE" ]; then
  echo "Error: Signed image not generated! Exiting."
  exit 1
fi

espsecure.py verify_signature -v 2 -k "$SIGNING_KEY" "$SIGNED_FILE"
