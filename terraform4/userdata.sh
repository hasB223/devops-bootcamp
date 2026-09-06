#!/bin/bash
# Install Docker (same method used in terraform3/userdata.sh)
curl -fsSL https://get.docker.com | sh

# Wait for the docker daemon to be ready
until docker info >/dev/null 2>&1; do
  sleep 2
done

# Deploy Rackula via docker compose (persistent layout/settings store)
# Official: https://github.com/RackulaLives/Rackula
mkdir -p /opt/rackula && cd /opt/rackula

curl -fsSL \
  https://raw.githubusercontent.com/RackulaLives/Rackula/main/deploy/docker-compose.persist.yml \
  -o docker-compose.yml

mkdir -p data && chown 1001:1001 data

docker compose up -d