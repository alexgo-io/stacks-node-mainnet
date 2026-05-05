# stacks-node-mainnet

Docker-based setup for running a Stacks blockchain node on mainnet.

## Prerequisites

- **OS:** Debian 12 or Ubuntu 22.04+
- **RAM:** Minimum 8GB, recommended 16GB
- **Disk:** Minimum 200GB SSD
- **Docker:** Installed automatically by setup script

## Quick Start

### Option 1: From Cold Backup (Recommended)

This is the fastest method using pre-built snapshots.

```bash
# Clone the repository
git clone https://github.com/alexgo-io/stacks-node-mainnet.git
cd stacks-node-mainnet

# Install prerequisites (requires root)
sudo ./setup.sh
# Reboot the server after setup

# Download latest backup from releases
# https://github.com/alexgo-io/stacks-node-mainnet/releases

# Start the node
./start.sh

# Check sync status
./health-check.sh
```

### Option 2: From Archive

Build from the official Hiro archive (takes longer).

```bash
# Prerequisites
sudo ./setup.sh

# In terminal 1: Restore PostgreSQL
./restore-archive-pg.sh

# In terminal 2: Restore Stacks node
./restore-archive-node.sh

# Start all services
./start.sh
```

## Available Commands

| Command | Description |
|---------|-------------|
| `./start.sh` | Start all services |
| `./stop.sh` | Stop all services (graceful shutdown) |
| `./health-check.sh` | Check node sync status |
| `make help` | Show all available make commands |

Or use the Makefile:

```bash
make start    # Start services
make stop     # Stop services
make logs     # View logs
make health   # Check sync status
make status   # Show container status
```

## Configuration

- Copy `.env.example` to `.env` for custom environment variables
- Copy `docker-compose.override.yml.example` for Docker customizations
- Edit `config/Stacks.toml` for node configuration

## Security Note

The default PostgreSQL password is set in `docker-compose.yml`. For production use:
1. Change the password in `docker-compose.yml`
2. Or use `docker-compose.override.yml` with environment variables
3. Ensure firewall blocks external access to port 5432

## Ports

| Port | Service |
|------|---------|
| 3999 | Stacks API (public) |
| 20443 | Stacks Node RPC |
| 20444 | Stacks Node P2P |
| 5432 | PostgreSQL (local only) |

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

## References

- [Stacks Nodes Documentation](https://docs.stacks.co/guides-and-tutorials/nodes-and-miners)
- [Hiro Archive](https://docs.hiro.so/stacks/archive)

## License

[MIT](LICENSE)
