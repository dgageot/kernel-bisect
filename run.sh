#!/bin/bash

export CLOUDSDK_CORE_PROJECT='code-story-blog'
export CLOUDSDK_COMPUTE_ZONE='europe-west1-d'

TARBAL='/Users/dgageot/go/src/github.com/docker/moby/alpine/gce.img.tar.gz'
BUCKET='docker-image'
TAG="${TAG:-latest}"

echo Upload tarball
gsutil cp -a public-read "${TARBAL}" "gs://${BUCKET}/${TAG}/moby.img.tar.gz"

echo Create GCE image
gcloud compute images delete -q "moby-${TAG}" | true
gcloud compute images create --source-uri "https://storage.googleapis.com/${BUCKET}/${TAG}/moby.img.tar.gz" "moby-${TAG}"

echo Create nodes
gcloud compute instances delete -q "manager-${TAG}" "worker-${TAG}" | true
gcloud compute instances create "manager-${TAG}" --image="moby-${TAG}" --machine-type="g1-small" --boot-disk-size=200 --metadata serial-port-enable=true --metadata-from-file startup-script=script-manager.sh
gcloud compute instances create "worker-${TAG}" --image="moby-${TAG}" --machine-type="g1-small" --boot-disk-size=200 --metadata serial-port-enable=true --metadata-from-file startup-script=script-worker.sh

echo Wait for the Swarm
MANAGER_IP=$(gcloud compute instances describe "manager-${TAG}" --format=json | jq -r '.networkInterfaces[0].accessConfigs[0].natIP')
echo $MANAGER_IP

for i in $(seq 1 10); do
  READY=$(curl -s $MANAGER_IP:8080)
  if [ $(echo ${READY} | grep -c Welcome) -eq 1 ]; then
    echo "Ready to test"
    READY=1
    break
  fi

  echo "Waiting for the Swarm"
  sleep 1
done

echo Test Routing Mesh
for i in $(seq 1 4); do
  curl -s --connect-timeout 10 $MANAGER_IP:5000
  if [ $? -ne 0 ]; then
    echo "FAILURE"
    exit 1
  fi
done

echo "SUCCESS"
exit 0
