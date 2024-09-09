#!/usr/bin/env bash

# Load environment variables from .env file
if [ -f .env ]; then
    source ./.env
else
    echo "Error: .env file not found."
    exit 1
fi


# Check for podman
if ! command -v podman &>/dev/null; then
    echo "Error: 'podman' is not installed."
    exit 1
fi

# Check for podman-compose
if ! command -v podman-compose &>/dev/null; then
    echo "Error: 'podman-compose' is not installed."
    exit 1
fi

# Bring down any existing containers and clean up volumes
echo "Running podman-compose down -v && podman volume prune --force"
podman-compose down -v && podman volume prune --force


# Run podman-compose up 
echo "Running podman-compose up -d "
podman-compose -f compose.yml up -d 
