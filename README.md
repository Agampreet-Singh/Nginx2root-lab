# nginx2root lab (clean rebuild)

Three nginx targets for the CVE-2026-123007 training lab:

| Target     | Port  | Version | Config                                  |
|------------|-------|---------|-----------------------------------------|
| vulnerable | 8443  | 1.31.8  | HTTP/2, HTTP/3, proxy, resolver+mirror  |
| patched    | 9443  | 1.31.9  | same as vulnerable                      |
| mitigated  | 10443 | 1.31.8  | HTTP/2+3 off, fixed upstream, no mirror |

`site/index.html` is exactly **896 bytes** — the calibrated resource the PoC's
safe oracle and the embedded 1.31.8 profile expect. Do not replace it with a
larger page; put any other content at a different path.

## Start

```bash
docker compose up -d --build        # ~3-5 min first time (builds nginx twice)
docker compose ps
```

Default publishes on all interfaces (0.0.0.0) so another machine can reach it.
For host-only: `BIND=127.0.0.1 docker compose up -d --build`.

> WARNING: the vulnerable target is intentionally insecure. Only run it on an
> isolated/trusted lab network. Never expose it to the internet.

## Check exposure

```bash
chmod +x check.sh
./check.sh                 # localhost
./check.sh <host-ip>:8443 <host-ip>:9443 <host-ip>:10443
```

## Prove the bug with the PoC

Build the PoC separately (see its own README), then from the ATTACKER machine:

```bash
poc --host https://<host-ip>:8443 --safe     # VULNERABLE
poc --host https://<host-ip>:9443 --safe     # NOT PROVEN (patched)
```

### IMPORTANT: the oracle needs a real network path

The safe oracle works by applying TCP backpressure to keep nginx's response
DATA queued. **Loopback (127.0.0.1) has no real backpressure**, so a localhost
test reports NOT PROVEN even against the vulnerable target. Prove it:

- **across the network** (attacker box -> this host's LAN IP), or
- **against the container bridge IP on port 443** (see `demo.sh`), or
- from a VM / second machine on a host-only network.

A single-host loopback run is not a valid test — that's a teaching point, not a
bug.

## Tear down

```bash
docker compose down --rmi local
```
