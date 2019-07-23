#!/bin/sh
set -e

echo '### Cleanup k3s'
docker-compose stop
docker-compose rm -fv
echo
