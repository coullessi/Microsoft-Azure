#!/bin/bash

sudo touch ~/.ssh/known_hosts ~/.ssh/known_hosts.old
sudo chown lessi:lessi ~/.ssh/known_hosts ~/.ssh/known_hosts.old
echo
# echo "Add the key of the managed nodes to the known_hosts file by running the following command:"
# echo "ssh-keyscan -H 'target_host' >> ~/.ssh/known_hosts"