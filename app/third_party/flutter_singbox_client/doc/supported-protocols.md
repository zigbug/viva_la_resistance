# Supported Protocols & Features

> All protocols and features listed here are provided by the [Sing-box](https://github.com/SagerNet/sing-box) core bundled with this SDK (`1.14.0-alpha.20`). Feature availability may vary by platform and core version.

---

## Inbound Protocols

| Protocol | Description |
|---|---|
| `direct` | Accept connections and forward directly |
| `mixed` | Combined SOCKS4/4a/5 and HTTP proxy |
| `socks` | SOCKS4/4a/5 proxy with optional auth |
| `http` | HTTP/HTTPS proxy with optional auth |
| `shadowsocks` | Multi-user, SIP003 plugins, SS2022 |
| `vmess` | V2Ray VMess with AEAD encryption |
| `vless` | Lightweight V2Ray protocol with flow control |
| `trojan` | Password-based with fallback routing |
| `naive` | HTTP/2 CONNECT tunneling with TLS |
| `hysteria` | QUIC-based with bandwidth management |
| `hysteria2` | Enhanced QUIC with Salamander obfuscation |
| `tuic` | QUIC-based with zero-RTT handshake |
| `shadowtls` | TLS handshake masquerading (v1/v2/v3) |
| `anytls` | Generic TLS-based protocol |
| `tun` | Transparent proxy via virtual TUN interface |
| `redirect` | TCP redirect (Linux) |
| `tproxy` | Transparent proxy for TCP and UDP (Linux) |
| `cloudflared` | Cloudflare Tunnel inbound |

---

## Outbound Protocols

| Protocol | Description |
|---|---|
| `direct` | Connect without a proxy |
| `block` | Drop matching connections |
| `socks` | SOCKS5 outbound proxy |
| `http` | HTTP/HTTPS outbound proxy |
| `shadowsocks` | SS2022 and legacy ciphers |
| `vmess` | VMess with transport and TLS |
| `vless` | VLESS with XTLS Vision flow |
| `trojan` | Trojan with optional multiplex |
| `naive` | Naive proxy outbound |
| `wireguard` | WireGuard with multi-peer support |
| `hysteria` | Hysteria QUIC outbound |
| `hysteria2` | Hysteria2 with port hopping |
| `tuic` | TUIC with BBR/CUBIC congestion control |
| `shadowtls` | ShadowTLS outbound |
| `anytls` | AnyTLS outbound |
| `tor` | Tor network outbound |
| `ssh` | SSH tunnel outbound |
| `dns` | DNS outbound for rule-based DNS routing |
| `selector` | Manual outbound selection via Clash API |
| `urltest` | Automatic selection by latency health check |

---

## Transports (V2Ray)

| Transport | Description |
|---|---|
| `http` | HTTP/1.1 transport layer |
| `ws` | WebSocket with custom path and headers |
| `grpc` | gRPC with service name configuration |
| `httpupgrade` | HTTP Upgrade (WebSocket-like) |
| `quic` | QUIC transport |

---

## TLS & Security

| Feature | Description |
|---|---|
| TLS 1.0 – 1.3 | Configurable minimum/maximum TLS version |
| uTLS | ClientHello fingerprint spoofing (Chrome, Firefox, Safari, Edge, …) |
| Reality | TLS handshake masquerading with short ID and public key |
| ECH | Encrypted Client Hello |
| Mutual TLS | Client certificate authentication |
| Certificate pinning | SHA-256 public key pinning |
| Custom cipher suites | Explicit cipher suite selection |
| ACME | Automatic certificate provisioning (Let's Encrypt / ZeroSSL) |

---

## DNS

| Feature | Description |
|---|---|
| UDP / TCP | Standard DNS |
| DoT | DNS over TLS |
| DoH / DoH3 | DNS over HTTPS (HTTP/1.1 and HTTP/3) |
| DoQ | DNS over QUIC |
| FakeIP | Return synthetic IPs for rule-based routing |
| DHCP | Read system DHCP-assigned DNS servers |
| mDNS | Multicast DNS |
| Rule-based routing | Route queries by domain, IP, protocol, process, and more |
| LRU cache | Configurable capacity with optimistic caching |
| EDNS0 client subnet | Forward client subnet in queries |
| Reverse mapping | IP-to-domain resolution for connection info |

---

## Routing & Rules

| Capability | Description |
|---|---|
| Domain matching | Exact, suffix, keyword, and regex |
| IP / CIDR matching | IPv4 and IPv6 CIDR blocks, private IP detection |
| GeoIP / Geosite | Geographic database matching (built-in rule-set format) |
| Port matching | Specific ports and port ranges |
| Protocol sniffing | Detect HTTP, TLS, DNS, QUIC, STUN, and more |
| Process matching | Match by process name, path, or UID (Linux/Windows/macOS) |
| Android packages | Match by package name or regex |
| Network state | WiFi SSID/BSSID, network type, metered flag |
| Logical rules | Combine rules with AND / OR operators |
| Rule-sets | Reusable rule bundles (local file or remote URL) |
| Clash mode | Route based on active global Clash mode |

---

## TUN / VPN

| Feature | Description |
|---|---|
| TCP/IP stacks | `system`, `gVisor`, or `mixed` |
| IPv4 & IPv6 | Dual-stack prefix configuration |
| DNS hijack | Intercept and redirect DNS queries |
| Strict routing | Block traffic not routed through the tunnel |
| Endpoint-independent NAT | Full-cone NAT for UDP |
| GSO | Generic Segmentation Offload |
| Interface / UID / package filtering | Fine-grained routing exclusions (Linux / Android) |
| nftables auto-redirect | Automatic redirect rules on Linux |
| MPTCP bypass | Exclude MPTCP connections from TUN (Linux) |

---

## Obfuscation & Anti-Censorship

| Technology | Description |
|---|---|
| ShadowTLS v3 | Authentic TLS handshake with wildcard SNI rewriting |
| Reality | Steals a real TLS certificate via short ID handshake |
| Hysteria2 Salamander | QUIC packet obfuscation with password |
| uTLS fingerprinting | Mimic real browser TLS ClientHello |
| SIP003 plugins | External obfuscation plugins for Shadowsocks (obfs, v2ray-plugin) |
| Naive padding | CONNECT-based HTTP/2 with traffic padding |
