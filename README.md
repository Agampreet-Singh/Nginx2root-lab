# nginx2root Lab — CVE-2026-123007

![Docker](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)
![nginx](https://img.shields.io/badge/nginx-1.31.8%20%7C%201.31.9-009639?logo=nginx&logoColor=white)
![Purpose](https://img.shields.io/badge/purpose-security%20training-red)

A self-contained, reproducible Docker lab for studying **CVE-2026-123007** in nginx.
It runs three targets side by side (vulnerable, patched and mitigated) so you can
reproduce the bug, confirm the fix, and check that the configuration workaround holds.
All three are built from the same sources.

> [!WARNING]
> The vulnerable target is **intentionally insecure**. Run this lab only on an
> isolated or trusted network that you control. **Never expose it to the internet.**

---

## Table of Contents

- [Lab Architecture](#lab-architecture)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Verify Exposure](#verify-exposure)
- [Exploitation](#exploitation)
- [Mitigation](#mitigation)
- [Troubleshooting](#troubleshooting)
- [Tear Down](#tear-down)
- [Disclaimer](#disclaimer)

---

## Lab Architecture

| Target         | Port    | nginx Version | Configuration                                   | Expected Result |
|----------------|---------|---------------|-------------------------------------------------|-----------------|
| **vulnerable** | `8443`  | 1.31.8        | HTTP/2, HTTP/3, proxy, resolver + mirror        | VULNERABLE      |
| **patched**    | `9443`  | 1.31.9        | Identical to vulnerable                         | NOT VULNERABLE  |
| **mitigated**  | `10443` | 1.31.8        | HTTP/2 + HTTP/3 off, fixed upstream, no mirror  | NOT VULNERABLE  |

The patched and mitigated targets are your controls. A PoC that reports the bug on
`8443` but not on `9443` or `10443` is behaving correctly.

### Calibrated test resource

`site/index.html` is exactly **896 bytes**. The PoC's safe oracle and its built-in
1.31.8 profile are calibrated to this size.

- **Do not** replace or enlarge this file.
- Put any extra content at a different path.

---

## Requirements

- Docker Engine 24+ with the Compose v2 plugin
- About 2 GB free disk space (nginx is compiled from source twice)
- A **second machine, VM or host-only network** for exploitation (see
  [Network path requirement](#network-path-requirement))

---

## Quick Start

```bash
git clone https://github.com/Agampreet-Singh/Nginx2root-lab.git
cd Nginx2root-lab
docker compose up -d --build     # first build takes ~3-5 minutes
docker compose ps
```

By default the targets listen on all interfaces (`0.0.0.0`) so an attacker machine
on the lab network can reach them. To bind to localhost only:

```bash
BIND=127.0.0.1 docker compose up -d --build
```

---

## Verify Exposure

Use the bundled checker to confirm each target is up and responding:

```bash
chmod +x check.sh
./check.sh                                              # localhost
./check.sh <host-ip>:8443 <host-ip>:9443 <host-ip>:10443  # remote
```

---

## Exploitation
### Using other public PoCs

The vulnerable target runs a **stock, unmodified nginx 1.31.8** with every affected
feature enabled (HTTP/2, HTTP/3, proxying, resolver and mirror). That makes it a
realistic target for PoCs and exploits written against CVE-2026-123007: a PoC that
works against a real affected server should behave the same way here.

Use the three targets to check any PoC:

1. **`8443` (vulnerable):** the PoC should succeed.
2. **`9443` (patched):** the PoC should fail. If it reports success here, it is
   giving a false positive.
3. **`10443` (mitigated):** the PoC should fail, which confirms the workaround works.

> [!CAUTION]
> **Review all third-party PoC code before you run it.** Fake "PoCs" for newly
> disclosed CVEs are a common way to spread malware, and they target security
> researchers in particular. Read the source, avoid prebuilt binaries from unknown
> authors, and run untrusted tools in a disposable VM, never on your host.

### Network path requirement

The safe oracle applies **TCP backpressure** to keep nginx's response DATA frames
queued. **Loopback (`127.0.0.1`) has no real backpressure**, so a localhost run
reports `NOT PROVEN` even against the vulnerable target.

Run the PoC over a real network path:

| Method | Example |
|--------|---------|
| Across the LAN | attacker box → `https://<host-lan-ip>:8443` |
| Container bridge IP | `https://<container-ip>:443` (see below) |
| Second VM / host-only network | attacker VM → lab VM |

To find the container bridge IP of the vulnerable target:

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  $(docker compose ps -q vulnerable)
```

> A single-host loopback result is **not a valid test**. This is expected
> behaviour and part of what the lab teaches, not a bug.

---

## Mitigation

If you cannot upgrade to **nginx 1.31.9** straight away, the `mitigated` target
shows a configuration workaround (see `conf/mitigated.conf`):

- Disable HTTP/2 and HTTP/3
- Use a fixed upstream instead of runtime `resolver` lookups
- Remove `mirror` directives

Compare the two configs to see exactly what changes:

```bash
diff conf/vulnerable.conf conf/mitigated.conf
```

**Upgrading to 1.31.9 or later is the recommended fix.**

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `NOT PROVEN` on `8443` | Testing over loopback | Use a real network path (see above) |
| `NOT PROVEN` on `8443` over the network | `site/index.html` was modified | Restore the original 896-byte file |
| Connection refused from attacker box | Lab bound to `127.0.0.1` | Restart without `BIND=127.0.0.1` |
| Build is slow | nginx compiles from source | Normal for the first build; later builds use the cache |

---

## Tear Down

```bash
docker compose down --rmi local
```

---

## Disclaimer

This project is for **education and authorized security testing only**. Only
test systems you own or have explicit written permission to test. The author
accepts no liability for misuse of this lab or of any tools used with it.

---

If this lab helped you, please give the repo a ⭐. Issues and pull requests are welcome.
