#!/bin/bash
source /usr/local/ansible/linux-automation-2.18-env/bin/activate
cd /usr/local/ansible/linux-automation-2.18-env/projects/linux-automation/ubuntu

export ANSIBLE_PASSWORD="$RD_OPTION_ANSIBLE_PASSWORD"
export GHOST_PASSWORD="$RD_OPTION_GHOST_PASSWORD"
/usr/local/ansible/linux-automation-2.18-env/bin/ansible-playbook \
  -e "ansible_user=ansible" \
  -i inventory.yml \
  Ubuntu_Patching_System.yml \
  -vvv