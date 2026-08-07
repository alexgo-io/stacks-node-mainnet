# PostgreSQL seccomp and authentication hardening

`postgres-no-connect-seccomp.json` is based on Moby's `seccomp/v0.2.1`
default profile, with `connect` and the legacy 32-bit `socketcall` multiplexer
removed from the allowlist. PostgreSQL can still listen for and accept client
connections, but `stacks_postgres` and commands executed inside it cannot
initiate TCP or Unix-socket connections.

This is not a complete egress firewall: connectionless datagrams such as
`sendto` are outside this profile's scope. A host firewall or network policy is
still required when every form of outbound IP traffic must be blocked.

The start script also atomically changes every active `trust` rule in the PG18
cluster's `pg_hba.conf` to `scram-sha-256`. It locates the versioned PG18 data
directory through its unique `PG_VERSION` file, verifies correct and incorrect
loopback password behavior from the host, checks the active HBA rules, and
confirms an outbound connection attempt from the container is denied.

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

Administrative `psql`, readiness, and restore commands must run from the host or
a separate client container after hardening; `docker exec stacks_postgres psql`
is intentionally unable to connect.
