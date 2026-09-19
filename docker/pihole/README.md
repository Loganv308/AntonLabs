# Nebula-Sync

Nebula-Sync is used to synchronize configuration between the two Pi-hole instances in the homelab.

## Architecture

```text
LAN Clients
    │
    ├── DNS → 10.10.0.152 (Primary Pi-hole)
    │
    └── DNS → 10.10.0.80  (Secondary Pi-hole)
                         │
                         └── Both use 10.10.0.1
                             (Cloud Gateway Fiber)
```

Nebula-Sync keeps the Pi-hole configurations synchronized. Gravity updates are handled separately by the primary Pi-hole's daily cron job.

## Directory Structure

```text
/opt/docker/nebula-sync/
├── docker-compose.yml
└── .env
```

## 1. Create the directory

```bash
sudo mkdir -p /opt/docker/nebula-sync
cd /opt/docker/nebula-sync
```

## 2. Create `.env`

Create the environment file:

```bash
nano .env
```

Add:

```env
PIHOLE_PRIMARY_URL=http://10.10.0.152
PIHOLE_PRIMARY_PASSWORD=YOUR_PRIMARY_PIHOLE_PASSWORD

PIHOLE_SECONDARY_URL=http://10.10.0.80
PIHOLE_SECONDARY_PASSWORD=YOUR_SECONDARY_PIHOLE_PASSWORD
```

Replace the passwords with the API passwords for the respective Pi-hole instances.

Protect the file:

```bash
chmod 600 .env
```

## 3. Create `docker-compose.yml`

```yaml
services:
  nebula-sync:
    image: ghcr.io/lovelaze/nebula-sync:latest
    container_name: nebula-sync
    env_file:
      - .env
    environment:
      - PRIMARY=${PIHOLE_PRIMARY_URL}|${PIHOLE_PRIMARY_PASSWORD}
      - REPLICAS=${PIHOLE_SECONDARY_URL}|${PIHOLE_SECONDARY_PASSWORD}
      - FULL_SYNC=false
      - RUN_GRAVITY=false
      - CLIENT_SKIP_TLS_VERIFICATION=true
      - SYNC_CONFIG_DNS=true
      - CRON=*/5 * * * *
    restart: unless-stopped
```

## 4. Start Nebula-Sync

```bash
docker compose up -d
```

Check that the container is running:

```bash
docker ps
```

You should see:

```text
nebula-sync
```

## 5. Check the logs

View the most recent logs:

```bash
docker logs nebula-sync --tail 100
```

Follow the logs:

```bash
docker logs -f nebula-sync
```

A successful synchronization should contain messages similar to:

```text
Authenticating clients...
Syncing teleporters...
Syncing configs...
Sync completed
```

## Configuration

| Setting | Value | Purpose |
|---|---|---|
| `FULL_SYNC` | `false` | Avoid a complete overwrite of the replica |
| `RUN_GRAVITY` | `false` | Gravity is handled separately |
| `SYNC_CONFIG_DNS` | `true` | Synchronize Pi-hole DNS configuration |
| `CRON` | `*/5 * * * *` | Synchronize every 5 minutes |
| `CLIENT_SKIP_TLS_VERIFICATION` | `true` | Allows HTTP/self-signed TLS connections |

## Gravity

Gravity is **not** managed by Nebula-Sync.

The primary Pi-hole runs Gravity daily at 3:00 AM:

```cron
0 3 * * * /usr/local/bin/pihole -g >/var/log/pihole-gravity.log 2>&1
```

Verify the cron job:

```bash
sudo crontab -l
```

Verify the Gravity log:

```bash
sudo tail -50 /var/log/pihole-gravity.log
```

## DNS Architecture

Both Pi-hole instances should use the Cloud Gateway Fiber as their upstream DNS server:

```text
Pi-hole 10.10.0.152
        ↓
     10.10.0.1

Pi-hole 10.10.0.80
        ↓
     10.10.0.1
```

Do **not** configure either Pi-hole to use the other Pi-hole as its upstream DNS server.

Clients should receive both Pi-hole addresses through DHCP:

```text
DNS 1: 10.10.0.152
DNS 2: 10.10.0.80
```

This allows clients to continue resolving DNS if either Pi-hole becomes unavailable.

## Useful Commands

### Restart Nebula-Sync

```bash
docker compose restart nebula-sync
```

### Stop Nebula-Sync

```bash
docker compose down
```

### Update the container

```bash
docker compose pull
docker compose up -d
```

### Check container status

```bash
docker compose ps
```

### Follow logs

```bash
docker compose logs -f nebula-sync
```

## Troubleshooting

Test the primary Pi-hole:

```bash
dig google.com @10.10.0.152
```

Test the secondary:

```bash
dig google.com @10.10.0.80
```

Test the Cloud Gateway:

```bash
dig google.com @10.10.0.1
```

Check each Pi-hole's configured upstream DNS:

```bash
sudo pihole-FTL --config dns.upstreams
```

Both should point to:

```text
10.10.0.1
```

If Nebula-Sync fails to authenticate, verify the URLs and passwords in `.env` and check:

```bash
docker logs nebula-sync --tail 100
```

## Security

Do not commit `.env` to Git.

Add it to `.gitignore`:

```gitignore
.env
```

The `.env` file contains Pi-hole credentials and should remain private.
