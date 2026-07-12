CREATE USER stacks_blockchain_api;
GRANT ALL PRIVILEGES ON DATABASE stacks_blockchain_api TO stacks_blockchain_api;
CREATE SCHEMA stacks_blockchain_api;
ALTER DATABASE stacks_blockchain_api OWNER TO stacks_blockchain_api;
ALTER SCHEMA stacks_blockchain_api OWNER TO stacks_blockchain_api;
ALTER USER postgres WITH PASSWORD NULL;
