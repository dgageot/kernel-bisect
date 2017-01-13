set -x

docker swarm init
TOKEN=$(docker swarm join-token manager -q)
echo -e "HTTP/1.1 200 OK\n\n${TOKEN}" | nc -l -p 1500

READY=0
for i in $(seq 1 30); do
  if [ $(docker node ls | grep -c Ready) -eq 2 ]; then
    echo "Swarm is ready"
    READY=1
    break
  fi

  echo "Waiting for the other node"
  sleep 1
done

docker node ls

[ $READY -eq 1 ] || (echo Swarm not ready && exit 1)
echo "Swarm is ready"

docker network create --driver overlay test
docker service create --name sw -p 5000:5000 --network test mrjana/simpleweb simpleweb
docker service scale sw=2

READY=0
for i in $(seq 1 30); do
  if [ $(docker service ps sw | grep -v Pending | grep -c Running) -eq 2 ]; then
    READY=1
    break
  fi

  echo "Waiting for the service to scale"
  sleep 1
done

docker service ps sw

docker run -d -p 8080:80 nginx:1.10.2-alpine
