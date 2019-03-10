#!/bin/bash

terraform apply -auto-approve

echo "Waiting for the created resource to settle..."
sleep 20

source .env

counter=1
until ping -c1 $DEPLOYING_HOST &>/dev/null; do 
  echo "$counter. Ping to $DEPLOYING_HOST unsuccessful..."
  let counter=counter+1
  sleep 5
done

ssh-keyscan -t rsa $DEPLOYING_HOST >> ~/.ssh/known_hosts
ssh-keyscan -t rsa $DEPLOYING_DOMAIN >> ~/.ssh/known_hosts

fab -p $PRIVATE_KEY_PASSWD bootstrap

./config_jenkins_server.sh
