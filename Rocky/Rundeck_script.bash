#!/bin/bash
source /usr/local/ansible/linux-automation-2.18-env/bin/activate
cd /usr/local/ansible/linux-automation-2.18-env/projects/linux-automation/rocky

export ANSIBLE_PASSWORD="$RD_OPTION_ANSIBLE_PASSWORD"
export GHOST_PASSWORD="$RD_OPTION_GHOST_PASSWORD"
/usr/local/ansible/linux-automation-2.18-env/bin/ansible-playbook \
  -e "ansible_user=ansible" \
  -i inventory.yml \
  rocky-test.yml \
  -vvv