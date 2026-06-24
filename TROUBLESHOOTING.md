# Troubleshooting Guide

## Common Issues

### 1. Containers not starting

**Symptom:** `docker-compose up` fails or containers exit immediately.

**Solutions:**
- Check if Docker is running: `systemctl status docker`
- View container logs: `docker-compose logs`
- Ensure ports are not in use: `netstat -tulpn | grep -E '3999|5432|20443'`

### 2. Node not syncing

**Symptom:** Block height is stuck or not increasing.

**Solutions:**
- Check node logs: `docker logs stacks_node`
- Verify network connectivity to peers
- Ensure sufficient disk space: `df -h`
- Check if API is responding: `curl http://127.0.0.1:3999/extended`

### 3. Database connection errors

**Symptom:** API cannot connect to PostgreSQL.

**Solutions:**
- Verify PostgreSQL is running: `docker logs stacks_postgres`
- Check if port 5432 is accessible: `nc -zv 127.0.0.1 5432`
- Ensure database credentials match in `docker-compose.yml`

### 4. Out of memory errors

**Symptom:** Containers are killed or restart frequently.

**Solutions:**
- Check available memory: `free -h`
- Increase swap space
- Adjust `shm_size` in docker-compose.yml for PostgreSQL
- Minimum recommended: 8GB RAM, 16GB recommended

### 5. Disk space issues

**Symptom:** Node stops syncing, database errors.

**Solutions:**
- Check disk space: `df -h`
- The full node requires approximately 150GB+ of disk space
- Consider using a larger volume or cleaning old data

## Useful Commands

```bash
# View all container logs
docker-compose logs -f

# Check specific container
docker logs stacks_node
docker logs stacks_api
docker logs stacks_postgres

# Restart a specific service
docker-compose restart stacks-blockchain-api

# Check resource usage
docker stats

# Verify node sync status
./health-check.sh
```

## Getting Help

If you're still experiencing issues:
1. Check the [Stacks documentation](https://docs.stacks.co/)
2. Search existing [GitHub issues](https://github.com/alexgo-io/stacks-node-mainnet/issues)
3. Open a new issue with detailed logs and system information
