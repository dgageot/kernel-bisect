set -x

docker pull mrjana/simpleweb

MANAGER=${HOSTNAME/worker/manager}
TOKEN=$(curl -s --retry-connrefused --retry 20 $MANAGER:1500)
docker swarm join --token $TOKEN $MANAGER:2377
