# stacks-node-mainnet

References:

+ https://docs.hiro.so/stacks-blockchain-api/how-to-guides/how-to-run-mainnet-node
+ https://docs.hiro.so/hiro-archive/overview

Note: **use `stop.sh` to shutdown daemons!**

## How to spin up a stacks-node from archive

The scripts works on debian 11. And always check if you're using the latest versions in `docker-compose.yml`.

```bash
# prerequisites
./setup.sh
```

Start 2 terminals to restore stacks node and postgres.

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

Check if blocks catch up with official node: `https://api.hiro.so/v2/info`

```bash
curl http://127.0.0.1:20443/v2/info
```
