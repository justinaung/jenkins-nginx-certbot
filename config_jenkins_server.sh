#!/bin/bash

source .env

ansible-playbook ./server_config/deploy.yml \
--private-key=./ssh_keys/jenkins.myantype.com/deployer_key \
-u deployer \
-i ./server_config/hosts \
