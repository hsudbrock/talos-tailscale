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
dns:
  magic_dns: false
  override_local_dns: false
  base_domain: __HEADSCALE_BASE_DOMAIN__
  nameservers:
    global: []
unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
log:
  format: text
  level: info
database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite
