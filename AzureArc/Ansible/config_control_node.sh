#!/bin/bash

echo "####################################################################"
echo "Creating the known_hosts file to store the keys of the managed nodes"
echo "####################################################################"
sudo touch ~/.ssh/known_hosts ~/.ssh/known_hosts.old
sudo chown lessi:lessi ~/.ssh/known_hosts ~/.ssh/known_hosts.old
echo

echo "####################################################################"
echo "Creating a private/public key pair to automate ansible tasks"
echo "Press Enter to continue twice when prompted for passphrase"
echo "####################################################################"
echo
sudo ssh-keygen -t rsa -C 'ControlNode' -f ~/.ssh/ControlNodeKey
sudo chown lessi:lessi ~/.ssh/ControlNodeKey ~/.ssh/ControlNodeKey.pub
echo
echo "####################################################################"
echo    "Create a config file to store ansible control node private key"
echo "####################################################################"
sudo touch ~/.ssh/config # comment this line if the ~/.ssh/config file already exist
sudo chown lessi:lessi ~/.ssh/config
echo "IdentityFile ~/.ssh/ControlNodeKey" >> ~/.ssh/config
echo

echo "####################################################################"
echo                          Installing Ansible
echo "####################################################################"

echo "Install pipx and ansible"
echo
sudo apt update
sudo apt install pipx
	
pipx install --include-deps ansible
pipx ensurepath
pipx upgrade --include-injected ansible
pipx inject ansible argcomplete
pipx inject --include-apps ansible argcomplete
activate-global-python-argcomplete3 --user
sudo pipx ensurepath
echo
echo
echo "Ansible installed successfully, type 'exit' to exit the shell"
echo "Start a new shell and run 'ansible --version' to check the version of ansible installed"
