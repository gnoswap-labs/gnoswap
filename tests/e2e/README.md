# IBC E2E Scaffold

This directory ports the IBC transfer e2e structure from `allinbits/gno-realms#14`.

## Test cases

- `TestIBCTransferAtomOneToGno`
- `TestIBCTransferGnoToAtomOne`

## Quick start

1. Copy environment file:

```bash
cp .env.example .env
```

2. Run full flow:

```bash
make test
```

3. Or run step-by-step:

```bash
make up
make logs
make test-only
make down
```

4. Keep services running after test:

```bash
make test-keep-up
```

## Notes

- This scaffold is local-first. For devnet bridging later, swap environment values and relayer path endpoints.
- Docker images currently build from upstream branches used in PR #14 patterns.
- `make test` and `make test-only` now use local Go caches at `tests/e2e/.cache/` by default to avoid host-level Go cache permission issues.
- Override cache paths if needed: `make test GOMODCACHE=/tmp/e2e-modcache GOCACHE=/tmp/e2e-gocache`.

## Endpoint configuration

- `GNO_GNOKEY_REMOTE` is used by `gnokey` commands (`-remote`) in tests. Default is `localhost:26657`.
- `GNO_REST` is reserved for future REST/web checks. Default is `http://localhost:8888`.
- `RELAYER_ATOMONE_RPC_URL` is used by relayer source RPC (`--surl`). Default is `http://atomone:26657`.
- `RELAYER_GNO_RPC_URL` is used by relayer destination RPC (`--durl`). Default is `http://gno:26657`.
- `INDEXER_QUERY_URL` is used by relayer destination query endpoint (`--dquery`). Default is `http://tx-indexer:8546/graphql/query`.
