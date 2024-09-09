#!/usr/bin/env bash

set -e

# Load environment variables from .env file located in the current directory
if [ -f .env ]; then
    source ./.env
else
    echo ".env file not found. Please make sure it exists in the same directory as this script."
    exit 1
fi

# Determine which script to run based on the preferred format
CERT_FORMAT=${KAFKA_TLS_TYPE:-"PEM"} # Default to PEM if not set

if [ "$CERT_FORMAT" == "JKS" ]; then
    echo "Generating JKS Certs and Stores...."
    ./scripts/jks-stores-gen.sh
else
    echo "Invalid certificate format specified. Please set CERT_FORMAT to 'JKS' in the .env file."
    exit 1
fi

./scripts/run_podman_compose.sh