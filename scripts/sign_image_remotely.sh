#!/bin/sh

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <input_binary_filename>"
  exit 1
fi

# Get the binary filename from the argument
BINARY_FILE="$1"

# Define output filenames based on the input binary
SIGNED_FILE="${BINARY_FILE%.bin}_signed_cryptera.bin"
SIGNATURE_FILE="${BINARY_FILE%.bin}_signed_cryptera.bin"
PUBLIC_KEY="${BINARY_FILE%.bin}_pubkey_cryptera.pem"

echo -----------------------
echo Requesting Authorization token
echo -----------------------
# Retrieve authentication token - on GitLab this is done by a secret variable in the pipeline
export KSC_ID_TOKEN=$(curl -sS --tlsv1.3 -X POST -H "Authorization: Basic YWRtaW5jbGllbnQ6cGFzc3dvcmQ=" -d "grant_type=client_credentials" https://authserver.forest-comet.cryptera.com:8300/oauth2/token | jq -r .access_token)
echo Token ID: $KSC_ID_TOKEN


echo -----------------------
echo Requesting pipeline operation
echo -----------------------
# Request a pipeline operation
export KSC_OPERATION_ID=$(curl -sS --tlsv1.3 -X 'POST' \
  'https://keyserver.forest-comet.cryptera.com:8200/api/operations' \
  -H "Authorization: Bearer $KSC_ID_TOKEN" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "validms": 60000,
  "description": "Building of mcuboot firmware for HVAC IoT board",
  "new-keyusagerestrictions": [
    {
      "keyid": "key4",
      "maxusagecount": 1
    }
  ]
}' | jq -r .id)
echo Operation ID: $KSC_OPERATION_ID


echo -----------------------
echo Approving pipeline operation
echo -----------------------
# Approve above pipeline operation
curl -sS --tlsv1.3 -X 'PUT' \
  "https://keyserver.forest-comet.cryptera.com:8200/api/approvals/$KSC_OPERATION_ID" \
  -H "Authorization: Bearer $KSC_ID_TOKEN" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json'

echo " "
echo Operation approved
echo -----------------------


export KSC_API_SERVER="https://keyserver.forest-comet.cryptera.com:8200"
export KSC_OPERATION_DESCRIPTION="Building of mcuboot firmware for HVAC IoT board"
export OPENSSL_CONF=/home/naneq/cryptera_signing_client/openssl-ks.cnf


echo -----------------------
echo Sign data with key4
openssl dgst -engine pkcs11 -keyform engine  -sign "pkcs11:object=key4" -sha256 -out "$SIGNATURE_FILE" "$BINARY_FILE"

# Check if the signature file was created
if [ ! -f "$SIGNATURE_FILE" ]; then
  echo " "
  echo "Error: Signature file not created! Exiting."
  exit 1
fi

echo -----------------------
echo Retrieve the certificate of the key and convert to PEM
pkcs11-tool --module /home/naneq/cryptera_signing_client/output/libpkcs11keyserver.so --read-object --type cert --label key4 --output-file cryptera_certkey.der

# Check if the key certificate exists
if [ ! -f "cryptera_certkey.der" ]; then
  echo " "
  echo "Error: Key certificate file doesn't exist! Exiting."
  exit 1
fi

openssl x509 -pubkey -noout -inform DER -in cryptera_certkey.der -out "$PUBLIC_KEY" -outform PEM

# Check if the key pem file was created
if [ ! -f "$PUBLIC_KEY" ]; then
  echo " "
  echo "Error: Key pem file not created! Exiting."
  exit 1
fi

echo Verification of signature for data
if ! openssl dgst -sha256 -verify "$PUBLIC_KEY" -signature "$SIGNATURE_FILE" "$BINARY_FILE"; then
  echo "Error: Signature verification failed! Exiting."
  exit 1
fi

echo -----------------------

rm cryptera_certkey.der

echo -----------------------
echo "Attach signature to the image"
echo -----------------------

if ! espsecure.py sign_data -v 2 --pub-key "$PUBLIC_KEY" --signature "$SIGNATURE_FILE" -o "$SIGNED_FILE" "$BINARY_FILE"; then
  echo "Process failed! Exiting."
  exit 1
fi

echo "Signature attached successfully"
echo -----------------------

echo -----------------------
echo Verify the signed image
espsecure.py verify_signature -v 2 -k "$PUBLIC_KEY" "$SIGNED_FILE"
