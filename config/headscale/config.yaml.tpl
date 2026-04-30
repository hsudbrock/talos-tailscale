server_url: __HEADSCALE_SERVER_URL__
listen_addr: __HEADSCALE_LISTEN_ADDR__
metrics_listen_addr: __HEADSCALE_METRICS_LISTEN_ADDR__
grpc_listen_addr: __HEADSCALE_GRPC_LISTEN_ADDR__
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: __HEADSCALE_PREFIX_V4__
  v6: __HEADSCALE_PREFIX_V6__
derp:
  server:
    enabled: false
  urls:
    - https://controlplane.tailscale.com/derpmap/default
dns:
  magic_dns: true
  override_local_dns: true
  base_domain: __HEADSCALE_BASE_DOMAIN__
  nameservers:
    global:
__HEADSCALE_GLOBAL_DNS_RESOLVERS__
unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
log:
  format: text
  level: info
database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite
