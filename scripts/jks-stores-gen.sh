#!/usr/bin/env bash

set -eu

# Load environment variables from .env file located one directory above
if [ -f .env ]; then
    source ./.env
else
    echo ".env file not found in the parent directory. Please make sure it exists."
    exit 1
fi

# Variables
CONTAINER_HOSTNAMES=$(echo "${KAFKA_CONTAINER_HOSTNAMES:-"kafka.example.com"}" | awk '{$1=$1};1') # Clean up leading/trailing spaces
CERTIFICATE_PASSWORD=${KAFKA_CERTIFICATE_PASSWORD:-"password"}                                    # Default to "password" if not set
CERTS_FOLDER=${CERTS_FOLDER:-"./certs/jks"}                                                       # Default folder is "./certs/jks"
VALIDITY_IN_DAYS=3650

# Create certs folder if it doesn't exist
mkdir -p "$CERTS_FOLDER"

# File paths
CA_CERT="$CERTS_FOLDER/ca-cert.pem"
CA_CERT_SRL="$CERTS_FOLDER/ca-cert.srl"
CA_KEY="$CERTS_FOLDER/ca-key.pem"
TRUSTSTORE_JKS="$CERTS_FOLDER/kafka.truststore.jks"

# Check if all files already exist
all_files_exist=true
for hostname in $CONTAINER_HOSTNAMES; do
    KEYSTORE_JKS="$CERTS_FOLDER/${hostname}.server.keystore.jks"

    if [ ! -e "$KEYSTORE_JKS" ] || [ ! -e "$CA_CERT" ] || [ ! -e "$CA_KEY" ] || [ ! -e "$TRUSTSTORE_JKS" ]; then
        all_files_exist=false
        break
    fi
done

if [ "$all_files_exist" = true ]; then
    echo "All files already exist. Exiting script successfully."
    exit 0
else
    echo "Some files are missing. Deleting all files and the directory..."

    # Delete all files if they exist
    for hostname in $CONTAINER_HOSTNAMES; do
        KEYSTORE_JKS="$CERTS_FOLDER/${hostname}.server.keystore.jks"

        if [ -e "$KEYSTORE_JKS" ]; then
            rm -f "$KEYSTORE_JKS"
        fi
    done

    if [ -e "$TRUSTSTORE_JKS" ]; then
        rm -f "$TRUSTSTORE_JKS"
    fi

    # Remove the directory if it exists
    if [ -d "$CERTS_FOLDER" ]; then
        rm -rf "$CERTS_FOLDER"
    fi

    # Recreate the directory
    mkdir -p "$CERTS_FOLDER"
fi

# Generate CA private key and self-signed certificate
echo "Generating CA private key and self-signed certificate..."
openssl req -new -x509 -days $VALIDITY_IN_DAYS -keyout $CA_KEY -out $CA_CERT -passout pass:$CERTIFICATE_PASSWORD -subj "/CN=CA/O=Company/OU=Org"

# Create a single truststore and import the CA certificate
if [ ! -e "$TRUSTSTORE_JKS" ]; then
    echo "Creating truststore and importing CA certificate..."
    keytool -keystore $TRUSTSTORE_JKS -alias CARoot -import -file $CA_CERT -storepass $CERTIFICATE_PASSWORD -noprompt
    echo "Generated truststore and stored CA certificate in $TRUSTSTORE_JKS."
else
    echo "Truststore already exists. Skipping creation."
fi

# Generate private key and certificate signing request (CSR) for each hostname
for hostname in $CONTAINER_HOSTNAMES; do
    KEYSTORE_JKS="$CERTS_FOLDER/${hostname}.server.keystore.jks"
    KEYSTORE_CSR="$CERTS_FOLDER/${hostname}-keystore.csr"

    echo "Generating private key and CSR for keystore $hostname..."
    keytool -keystore $KEYSTORE_JKS -alias $hostname -genkey -keyalg RSA -validity $VALIDITY_IN_DAYS -keysize 2048 \
        -dname "CN=$hostname, O=Company, OU=Org" -storepass $CERTIFICATE_PASSWORD -keypass $CERTIFICATE_PASSWORD

    keytool -keystore $KEYSTORE_JKS -alias $hostname -certreq -file $KEYSTORE_CSR -storepass $CERTIFICATE_PASSWORD

    # Sign the keystore certificate with the CA certificate
    echo "Signing the keystore certificate for $hostname with the CA certificate..."
    openssl x509 -req -in $KEYSTORE_CSR -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out "$CERTS_FOLDER/${hostname}-cert-signed.pem" -days $VALIDITY_IN_DAYS -passin pass:$CERTIFICATE_PASSWORD

    # Import the CA certificate and the signed certificate back into the keystore
    echo "Importing CA certificate and signed certificate into the keystore for $hostname..."
    keytool -keystore $KEYSTORE_JKS -alias CARoot -import -file $CA_CERT -storepass $CERTIFICATE_PASSWORD -noprompt
    keytool -keystore $KEYSTORE_JKS -alias $hostname -import -file "$CERTS_FOLDER/${hostname}-cert-signed.pem" -storepass $CERTIFICATE_PASSWORD -noprompt

    # Clean up intermediate files
    rm -f "$CERTS_FOLDER/${hostname}-cert-signed.pem" $CA_CERT_SRL $KEYSTORE_CSR
done

echo "All done!"
echo "Generated the following files in the '$CERTS_FOLDER' directory:"
for hostname in $CONTAINER_HOSTNAMES; do
    echo " - Keystore JKS for $hostname: $CERTS_FOLDER/${hostname}.server.keystore.jks"
done
echo " - Truststore JKS: $TRUSTSTORE_JKS"
