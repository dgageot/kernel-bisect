set -x

docker pull mrjana/simpleweb
docker swarm init
TOKEN=$(docker swarm join-token manager -q)
echo -e "HTTP/1.1 200 OK\n\n${TOKEN}" | nc -l -p 1500

READY=0
for i in $(seq 1 30); do
  echo "Waiting for the worker node"

  if [ $(docker node ls | grep -c Ready) -ne 2 ]; then
    sleep 1
    continue
  fi

  echo "Swarm is ready"
  READY=1
  break
done

docker node ls

[ $READY -eq 1 ] || (echo Swarm is not ready && exit 1)
echo "Swarm is ready"

docker network create --driver overlay test
docker service create --name sw -p 5000:5000 --mode=global --network test mrjana/simpleweb simpleweb

MANAGER=${HOSTNAME}
WORKER=${MANAGER/manager/worker}

READY=0
for i in $(seq 1 60); do
  echo "Waiting for the service to scale"

  if [ $(docker service ps sw --filter node=${MANAGER} --filter desired-state=running | grep -v Pending | grep -c Running) -ne 1 ]; then
    sleep 1
    continue
  fi
  if [ $(docker service ps sw --filter node=${WORKER} --filter desired-state=running | grep -v Pending | grep -c Running) -ne 1 ]; then
    sleep 1
    continue
  fi

  READY=1
  break
done

docker service ps sw

[ $READY -eq 1 ] || (echo Service couldnt scale && exit 1)
echo "Service has scaled on both nodes"

docker run -d -p 8080:80 nginx:1.10.2-alpine
