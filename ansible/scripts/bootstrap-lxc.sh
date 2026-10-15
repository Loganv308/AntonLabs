#!/usr/bin/env bash
set -euo pipefail

PVE_NODES=(10.10.0.10 10.10.0.25)   # <-- your node IPs
KEY=/root/.ssh/ansible_ed25519
OUT=/opt/Homelab-Ansible/Inventory/lxc.yaml
TMP=$(mktemp)
TARGETS="${*:-}"   # optional CTIDs, e.g. ./bootstrap-lxc.sh 105 112
trap 'rm -f "$TMP"' EXIT

[ -f "$KEY" ] || ssh-keygen -t ed25519 -f "$KEY" -N "" -C ansible
PUB=$(cat "$KEY.pub")

for node in "${PVE_NODES[@]}"; do
  echo "== Proxmox node $node"
  ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=accept-new root@"$node"

  ssh -i "$KEY" -o IdentitiesOnly=yes root@"$node" "PUB='$PUB' TARGETS='$TARGETS' bash -s" >> "$TMP" <<'REMOTE'
for id in $(pct list | awk 'NR>1 && $2=="running" {print $1}'); do
  name=$(pct config "$id" | awk '/^hostname:/ {print $2}')
  ip=$(pct exec "$id" -- ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
  if [ -z "$TARGETS" ] || [[ " $TARGETS " == *" $id "* ]]; then
    pct exec "$id" -- sh -c "mkdir -p /root/.ssh && chmod 700 /root/.ssh && touch /root/.ssh/authorized_keys && grep -qxF '$PUB' /root/.ssh/authorized_keys || echo '$PUB' >> /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys"
  fi
  echo "$name|$ip"
done
REMOTE
done

{
  echo "all:"
  echo "  children:"
  echo "    lxc:"
  echo "      hosts:"
  echo "== Hosts not yet in $OUT (paste under hosts: if wanted):"
  sort "$TMP" | while IFS='|' read -r name ip; do
    [ -z "$ip" ] && { echo "⚠️  $name: no IP found, skipped" >&2; continue; }
    grep -qE "^[[:space:]]+${name}:" "$OUT" 2>/dev/null && continue
    echo "        $name:"
    echo "          ansible_host: $ip"
  done
} > "$OUT"

echo "✅ Wrote $OUT"
