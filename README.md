# stacks-node-mainnet

References:

+ https://docs.hiro.so/stacks-blockchain-api/how-to-guides/how-to-run-mainnet-node
+ https://docs.hiro.so/hiro-archive/overview

Note: **use `stop.sh` to shutdown daemons!**

## How to spin up a stacks-node from cold backup

This is easiest and recommended way. The only caveat is the fixed password for postgres user. As long as you keep the firewall rejecting connections to postgres server, this won't be an issue; otherwise you'll have to change the password after restoring from backup and update the password configuration in `docker-compose.yml` accordingly.

The scripts are tested on debian 12. Clone this repo and follow the steps.

1. Run ./setup.sh and reboot the server
2. Restore the latest backup from https://github.com/alexgo-io/stacks-node-mainnet/releases
3. Run ./start.sh
4. Run `watch 'curl -s http://127.0.0.1:3999/extended'`, wait until the block height matches that from `https://api.hiro.so/v2/info`
5. Done

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
