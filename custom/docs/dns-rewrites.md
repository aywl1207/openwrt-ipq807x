# DNS Rewrites (LuCI)

Overlay under `custom/files/` — shipped in the rootfs image via `prepare.sh` → `files/`.

## Purpose

AGH-like rewrite UI without AdGuard Home:

| Type | dnsmasq effect |
|------|----------------|
| **Private IP** | `address=/domain/ip` + `local=/domain/` |
| **Public** | `server=/domain/127.0.0.1#5053` (DoH / Gateway) |

Avoids `cname=` under partial `local=` zones (unstable with musl/curl).

## Paths

| Path | Role |
|------|------|
| `/etc/config/dns_rewrite` | UCI list (site data = live / backup; empty in image) |
| `/usr/sbin/dns-rewrite-apply` | Generate conf + restart dnsmasq |
| `/etc/dnsmasq.d/10-dns-rewrites.conf` | Generated snippet |
| LuCI **Network → DNS Rewrites** | Editor |

Legacy UCI name `aykc_dns` is still read by the apply script if present.

## Policy

- Do **not** commit site-specific hostnames or tenant URLs to a public tree.
- Image ships empty `dns_rewrite` + tools; configure after flash or restore from backup.
- DNS changes: apply script / LuCI Save & Apply only — **never** `wifi reload`.
