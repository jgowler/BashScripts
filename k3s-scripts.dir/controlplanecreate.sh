#!/bin/bash

echo '---------------'
echo 'This script will now install the necessary files to'
echo 'assign this server as the Control Plane for'
echo 'your K3s cluster.'
echo 'You have 10 seconds to cancel (CTRL+C)'
echo '---------------'

# daemon reload
sudo systemctl daemon-reload

sleep 10

# install ACL
sudo apt-get install acl

echo "Checking for curl"

# Update the package list
sudo apt-get update

# Install curl
sudo apt-get install -y curl

# Verify curl installation
curl --version

# Create Firewall exceptions

echo 'Allowing connection to $HOST on port 8080/tcp'
sudo ufw allow 8080/tcp
echo 'Adding port exception for API server'
sudo ufw allow 6443/tcp #apiserver
echo 'Adding IP address range exception for Pods'
sudo ufw allow from 10.42.0.0/16 #pods
echo 'Adding IP address range exception for Services'
sudo ufw allow from 10.43.0.0/16 #services

# Install files

echo 'Beginning installation...'
sleep 5
echo 'This server will be the ETCD server.'
sleep 5

while true; do
	read -p 'Do you wish to assign the other control plane roles to this server? [API, Scheduler, Controller]? (Y/n):' choice
	# default option is Y/y/yes
	choice=${choice:-y}

	# convert choice to lowercase
	choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

	# Loop back if invalid choice selected

	if [[ $choice == "y" || "$choice" == "n" ]]; then
		break
	else
	echo "Invalid choice, please enter 'y', 'n', or hit Enter"
	fi
done

# Install selected server roles

if [ $choice == 'y' ]; then
	echo 'Assigning ETCD, API, Scheduler, and Controller roles to $(hostname)'
	curl -fL https://get.k3s.io | sh -s server --cluster-init
	echo 'All server roles have now been applied to $(hostname)'
elif [ $choice == "n"  ]; then
	echo 'Assigning just ETCD role to $HOSTNAME'
	curl -fL https://get.k3s.io | sh -s server --cluster-init \
	--disable-apiserver --disable-controller-manager --disable-scheduler
	echo 'ETCD server has now been applied to $(hostname)'
fi



echo '---------------'
echo '\ \ \ \ \ \ \ \'
echo '---------------'

# check if k3s is set to start with user log on already
if ! grep -q 'sudo systemctl start k3s' ~/.bashrc; then
	# append /.bashrc with K3S start command
	echo 'sudo systemctl start k3s' >> ~/.bashrc
	echo 'Added command to start K3S with user log on.'
else
	# ignore and move to next part of script
	echo '/.bashrc already contains command to start K3S with user log on'
fi

# check if alias to run kubectl commands is set in .bashrc
if ! grep -q "alias k='sudo kubectl'" ~/.bashrc; then
	# add the alias to the .bashrc file
	echo "alias k='sudo kubectl'" >> ~/.bashrc
	echo '---------------'
	echo "Alias 'k' has now been added (sudo kubectl command)"
	echo '---------------'
else
	# do not add redundat alias
	echo '---------------'
	echo "Alias 'k' (sudo kubectl) already exists in ~/.bashrc."
	echo '---------------'
fi

sudo kubectl get nodes
echo '---------------'

# create K3S group with access to /etc/rancher/k3s/k3s.yaml
sudo groupadd k3s-access

# add current user to this group
sudo usermod -aG k3s-access $(whoami)

echo '-------------------------------------------------------------------------'
echo 'The config file for this server is located at /etc/rancher/k3s/config.yaml'
sleep 5
echo 'The system will be rebooted in 10 seconds to allow changes to be applied.'
echo 'If you wish to postpone this use CTRL+C now to cancel.'
sleep 10
shutdown -r now
