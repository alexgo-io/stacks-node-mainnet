# PostgreSQL seccomp and authentication hardening

`postgres-no-connect-seccomp.json` is based on Moby's `seccomp/v0.2.1`
default profile, with `connect` and the legacy 32-bit `socketcall` multiplexer
removed from the allowlist. PostgreSQL can still listen for and accept client
connections, but `stacks_postgres` and commands executed inside it cannot
initiate TCP or Unix-socket connections.

This is not a complete egress firewall: connectionless datagrams such as
`sendto` are outside this profile's scope. A host firewall or network policy is
still required when every form of outbound IP traffic must be blocked.

The PostgreSQL start script also atomically changes every active `trust` rule in the PG18
cluster's `pg_hba.conf` to `scram-sha-256`. It locates the versioned PG18 data
directory through its unique `PG_VERSION` file, verifies correct and incorrect
loopback password behavior for `stacks_blockchain_api` from the host, and
confirms an outbound connection attempt from the container is denied. The
`postgres` superuser deliberately has a `NULL` password and is not used by
normal startup.

For an existing database:

```console
direnv exec . ./scripts/start-postgres.sh
```

For a deliberately new, empty `postgresql/` directory:

```console
direnv exec . ./scripts/start-postgres.sh --initialize
```

New database initialization temporarily uses Docker's built-in seccomp profile
because the official image runs an in-container `psql`. As soon as initialization
finishes, the script hardens HBA and recreates PostgreSQL with the no-connect
profile. If initialization or verification fails, it stops the temporarily
unrestricted or newly recreated container.

Do not persist `POSTGRES_SECCOMP_PROFILE=builtin`. The script sets `builtin`
only for fresh initialization and explicitly selects the hardened profile for
normal starts.

## Restoring a cold backup

A restored database can contain an application password from the machine that
created the backup. Adopt the password configured on the new host during the
first start only:

```console
direnv exec . ./start-from-cold-backup.sh
```

The wrapper runs `scripts/recover-restored-postgres-passwords.sh` before the
unchanged `start.sh`. Recovery starts a temporary container with Docker network
mode `none`, the no-connect seccomp profile, `listen_addresses` empty, and a
Unix socket in a private temporary directory. Its alternate HBA file permits
trust only on that temporary local socket; it does not edit or replace the
restored production HBA. The script sets `stacks_blockchain_api` to the current
`STACKS_PG_PASSWORD`, explicitly leaves `postgres` with `PASSWORD NULL`, verifies
both properties, and stops the temporary server before normal startup.

After the first successful recovery, use the normal command:

```console
direnv exec . ./start.sh
```

Administrative `psql`, readiness, and restore commands must run from the host or
a separate client container after hardening; `docker exec stacks_postgres psql`
is intentionally unable to connect.
