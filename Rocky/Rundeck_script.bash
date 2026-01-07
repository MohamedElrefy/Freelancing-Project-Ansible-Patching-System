#!/bin/bash
set -e  

source /storage/ansible/linux-automation/bin/activate
cd /storage/ansible/linux-automation/projects/rocky

if [ -z "$RD_OPTION_NAUTOBOT_TOKEN" ]; then
    echo "ERROR: Nautobot token not provided!"
    exit 1
fi

sed -i "s|token: PLACEHOLDER|token: $RD_OPTION_NAUTOBOT_TOKEN|" rocky-inventory.yml

cleanup() {
    sed -i "s|token: $RD_OPTION_NAUTOBOT_TOKEN|token: PLACEHOLDER|" rocky-inventory.yml
}

trap cleanup EXIT

/storage/ansible/linux-automation/bin/ansible-playbook \
  -e "ansible_user=ansible" \
  -i rocky-inventory.yml \
  rocky-production.yml \
  -vvv
