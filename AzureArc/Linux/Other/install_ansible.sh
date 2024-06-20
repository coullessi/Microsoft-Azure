#!/bin/bash

echo "############################################################"
echo                        Installing Ansible
echo "############################################################"

echo "Install pipx and ansible"
echo
sudo apt update
sudo apt install pipx
sudo pipx ensurepath
	
pipx install --include-deps ansible
pipx ensurepath
pipx upgrade --include-injected ansible
pipx inject ansible argcomplete
pipx inject --include-apps ansible argcomplete
pipx inject --include-apps ansible argcomplete
activate-global-python-argcomplete3 --user
echo
echo
echo "Ansible installed successfully, type 'exit' to exit the shell"
echo "Start a new shell and run 'ansible --version' to check the version of ansible installed"
