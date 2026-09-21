# Postgres Backup

Nightly logical backups of all PostgreSQL databases on a remote server, written to a TrueNAS NFS share via cron.

## What it does

`backup.sh`:
1. Dumps global objects (roles, tablespaces) with `pg_dumpall --globals-only --no-role-passwords`
2. Dumps every non-template, connectable database individually with `pg_dump -Fc` (custom/compressed format)
3. Verifies each output file is non-empty
4. Prunes dated backup folders older than `RETENTION_DAYS`
5. Logs everything to `backup.log` inside `BACKUP_ROOT`

Output layout:
```
$BACKUP_ROOT/
  backup.log
  2026-09-20/
    globals.sql
    mydb1.dump
    mydb2.dump
  2026-09-21/
    ...
```

## Setup

1. Copy files to the backup host:
   ```bash
   mkdir -p /opt/pg-backup
   cp backup.sh .env.example /opt/pg-backup/
   ```

2. Configure environment:
   ```bash
   cd /opt/pg-backup
   cp .env.example .env
   nano .env          # fill in real values
   chmod 600 .env
   chmod +x backup.sh
   ```

3. Test manually before trusting it to cron:
   ```bash
   env -i sh -c '. /opt/pg-backup/.env && /opt/pg-backup/backup.sh'
   tail -f "$BACKUP_ROOT/backup.log"
   ```

4. Add to root's crontab (`sudo crontab -e`) — runs nightly at 2:00 AM:
   ```
   0 2 * * * . /opt/pg-backup/.env && /opt/pg-backup/backup.sh
   ```

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `PGHOST` | yes | `localhost` | Postgres server address |
| `PGPORT` | no | `5432` | Postgres port |
| `PGUSER` | yes | `postgres` | Role to connect as (see permissions below) |
| `PGPASSWORD` | yes | *(empty)* | Password for `PGUSER` |
| `BACKUP_ROOT` | yes | `/mnt/truenas-backups/postgres` | Destination path (should be the mounted NFS share) |
| `RETENTION_DAYS` | no | `14` | Days of dated backup folders to keep |

`.env` lines must use `export VAR=value` so cron and manual test runs both pick them up correctly.

## Backup role permissions

The `PGUSER` role does **not** need superuser. Grant:

```sql
CREATE ROLE backup WITH LOGIN PASSWORD 'yourpassword';
GRANT pg_read_all_data TO backup;
```

`--no-role-passwords` on the `pg_dumpall` call avoids needing `pg_authid` access (superuser-only), so this is enough to dump every database's schema and data.

**Trade-off:** restoring `globals.sql` recreates roles without passwords. Reset them after a restore, or track passwords separately (e.g. a secrets manager, Ansible vault).

Also confirm `pg_hba.conf` on the Postgres server allows the backup host to connect, and that Postgres is listening on the network (`listen_addresses = '*'` in `postgresql.conf`, not just `localhost`).

## Restoring a backup

List contents without restoring:
```bash
pg_restore -l /path/to/mydb.dump
```

Restore into a new database:
```bash
createdb -h <host> -U <user> restored_db
pg_restore -h <host> -U <user> -d restored_db /path/to/mydb.dump
```

Restore globals (roles, tablespaces) — plain SQL, run directly:
```bash
psql -h <host> -U <user> -f globals.sql postgres
```

## Troubleshooting

- **`pg_dumpall`/`pg_dump: command not found`** — install client tools matching the server's major version (`apt install postgresql-client-<version>`, via the [PGDG apt repo](https://www.postgresql.org/download/linux/debian/) if your distro's default repo is older).
- **`server version mismatch`** — client tools are older than the server; install the matching major version.
- **`Connection refused`** — check `listen_addresses` in `postgresql.conf` and that Postgres was restarted after changing it.
- **`permission denied for table pg_authid`** — the role is missing `--no-role-passwords` on the `pg_dumpall` call, or you removed that flag; add it back.
- **`database "backup" does not exist`** — `psql`/`pg_dump` connect to a database matching the username by default; the script explicitly uses `-d postgres` for the database-listing query to avoid this.
- **Env vars not reaching the script under cron** — make sure every line in `.env` starts with `export`; a plain `VAR=value` sets a local shell variable but doesn't pass it to child processes like `pg_dump`.
