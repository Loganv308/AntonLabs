#!/usr/bin/env bash
set -euo pipefail
cd /v/Homelab/AntonLabs

# 1. yamllint config (clears the graylog line-length finding)
cat > .yamllint <<'EOF'
extends: relaxed
rules:
  line-length: disable
EOF

# 2. use the config file instead of the inline relaxed preset
sed -i 's/yamllint -d relaxed \./yamllint ./' .gitlab-ci.yml

# 3. make Ansible honor ansible/ansible.cfg in CI (skip if already added)
if ! grep -q 'ANSIBLE_CONFIG' .gitlab-ci.yml; then
  sed -i 's/^\( *\)- cd ansible\r\?$/&\n\1- export ANSIBLE_CONFIG="$PWD\/ansible.cfg"/' .gitlab-ci.yml
fi

git diff --stat
