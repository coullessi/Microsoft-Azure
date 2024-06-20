#!/bin/bash

echo "############################################################"
echo "Creating a private/public key pair to automate ansible tasks"
echo "Press Enter to continue twice when prompted for passphrase"
echo "############################################################"
echo
sudo ssh-keygen -t rsa -C 'ControlNode' -f ~/.ssh/ControlNodeKey
sudo chown lessi:lessi ~/.ssh/ControlNodeKey ~/.ssh/ControlNodeKey.pub
echo
echo "################################################################"
echo "Create a config file to store the private key of ansible control"
echo "################################################################"
sudo touch ~/.ssh/config # comment this line if the ~/.ssh/config file already exist
sudo chown lessi:lessi ~/.ssh/config
echo "IdentityFile ~/.ssh/ControlNodeKey" >> ~/.ssh/config
echo
# echo "Open the ~/.ssh/config file and add the following line: IdentityFile ~/.ssh/ControlNodeKey"
#echo "Save the file and exit the editor"