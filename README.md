# stacks-node-mainnet

References:

- https://docs.stacks.co/guides-and-tutorials/nodes-and-miners
- https://docs.hiro.so/stacks/archive

Note: **use `stop.sh` to shutdown daemons!**

## How to spin up a stacks-node from cold backup

Keep `STACKS_PG_PASSWORD` in the git-ignored `.envrc.override`, not in Compose.
PostgreSQL loopback connections require SCRAM authentication, and the database
container uses a no-connect seccomp profile. See `security/README.md`.

The scripts are tested on Debian 12. Clone this repo and follow the steps.

1. Run `./setup.sh` and reboot the server.
2. Put `STACKS_PG_PASSWORD` and the other host-specific settings in
   `.envrc.override`, run `chmod 600 .envrc.override`, then run `direnv allow`.
3. Restore both `postgresql/` and `stacks-node/` from the same cold-backup set at
   https://github.com/alexgo-io/stacks-node-mainnet/releases.
4. For the first start after restoring the backup, run:

   ```console
   direnv exec . ./start-from-cold-backup.sh
   ```

5. For every later normal start, continue to run:

   ```console
   direnv exec . ./start.sh
   ```

6. Run `watch 'curl -s http://127.0.0.1:3999/extended'` and wait until the block
   height matches `https://api.hiro.so/v2/info`.

The cold-backup wrapper starts PostgreSQL temporarily with no network and only
an isolated Unix socket. It sets the restored `stacks_blockchain_api` role to
`STACKS_PG_PASSWORD`, keeps the `postgres` role password `NULL`, stops recovery,
and then calls the unchanged normal `start.sh`. It never enables trust in the
restored cluster's production `pg_hba.conf`.

## How to spin up a stacks-node from archive

The scripts are tested on debian 12. Remember to check if you're using the latest versions in `docker-compose.yml` before following the steps below.

```bash
# prerequisites
./setup.sh
```

Start 2 terminals to restore stacks node and postgres, this will take a long time.

```bash
# terminal 1
./restore-archive-pg.sh
# terminal 2
./restore-archive-node.sh
```

Start all daemons

```bash
./start.sh
```

Check if everything works.

```bash
docker-compose logs -f
```

Wait until the block height catches up with official node: `https://api.hiro.so/v2/info`

```bash
watch 'curl -s http://127.0.0.1:3999/extended'
```
