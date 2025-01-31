#!/bin/sh

# Check if exactly two arguments are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <key_name> <pubkey_output_filepath>"
  exit 1
fi

# Get the key name from the argument
KEY_NAME="$1"

# Get the public key output filename from the argument
KEY_FILE="$2"

echo -----------------------
echo Request Authorization token
# Retrieve authentication token - on GitLab this is done by a secret variable in the pipeline
export KSC_ID_TOKEN=$(curl -sS --tlsv1.3 -X POST -H "Authorization: Basic YWRtaW5jbGllbnQ6cGFzc3dvcmQ=" -d "grant_type=client_credentials" https://authserver.forest-comet.cryptera.com:8300/oauth2/token | jq -r .access_token)

export KSC_API_SERVER="https://keyserver.forest-comet.cryptera.com:8200"
export KSC_OPERATION_DESCRIPTION="Building of mcuboot firmware for HVAC IoT board"
export OPENSSL_CONF=/home/naneq/cryptera_signing_client/openssl-ks.cnf

echo Retrieve the certificate of the key and convert to PEM
pkcs11-tool --module /home/naneq/cryptera_signing_client/output/libpkcs11keyserver.so --read-object --type cert --label ${KEY_NAME} --output-file cryptera_certkey.der

# Check if the key certificate exists
if [ ! -f "cryptera_certkey.der" ]; then
  echo " "
  echo "Error: Key certificate file doesn't exist! Exiting."
  exit 1
fi

openssl x509 -pubkey -noout -inform DER -in cryptera_certkey.der -out "$KEY_FILE" -outform PEM

rm cryptera_certkey.der

# Check if the key pem file was created
if [ ! -f "$KEY_FILE" ]; then
  echo " "
  echo "Error: Key pem file not created! Exiting."
  exit 1
fi

echo -----------------------
