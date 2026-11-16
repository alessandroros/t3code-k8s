# Accessing the server

The server listens on port 3773 in the pod (`service.port` 80 by default). Clients (desktop, iOS/Android, browser) connect over HTTP + WebSocket and authenticate with a one-time pairing link that becomes a long-lived session.

Whatever route you pick, set `t3.publicUrl` to the address clients use, so `t3-pair` prints a working link:

```bash
kubectl -n t3code exec -it t3-t3code-0 -c t3code -- t3-pair --label phone
# Pair URL: https://t3.home.lan/pair#token=…   (open it, or scan the QR from the app)
```

## 1. Port-forward (testing)

```bash
kubectl -n t3code port-forward svc/t3-t3code 3773:80
```

Open `http://localhost:3773` and pair with `t3.publicUrl=http://localhost:3773`.

## 2. VPN (WireGuard) + internal LoadBalancer IP

Good fit when the cluster already has MetalLB, kube-vip or Cilium LB-IPAM and your WireGuard peers can route to the LAN.

```yaml
service:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.240        # an address from your LB pool
  loadBalancerSourceRanges:
    - 10.8.0.0/24                      # WireGuard peers
    - 192.168.1.0/24                   # LAN
t3:
  publicUrl: http://192.168.1.240
networkPolicy:
  enabled: true
  ingress:
    from:
      - ipBlock: {cidr: 10.8.0.0/24}
      - ipBlock: {cidr: 192.168.1.0/24}
```

Things to check:

- **Routing**: the WireGuard peers' `AllowedIPs` must include the LB address (or the LAN it lives in), and the WireGuard endpoint must forward to the LAN.
- **Source IPs after NAT**: if the WireGuard host masquerades, the pod sees the WireGuard host's LAN address, not `10.8.0.x`. Either allow that address, or route without NAT. With `externalTrafficPolicy: Local` kube-proxy keeps the client IP, but the pod must run on the node that receives the traffic.
- **Plain HTTP**: fine on a VPN for the apps, but browsers limit some features outside a secure context. Prefer option 3 if you use the web client.

## 3. Internal ingress with TLS (recommended)

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: internal-ca        # or ACME with DNS-01
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: 50m    # attachments
    nginx.ingress.kubernetes.io/whitelist-source-range: 10.8.0.0/24,192.168.1.0/24
  hosts:
    - host: t3.home.lan
      paths: [{path: /, pathType: Prefix}]
  tls:
    - secretName: t3-tls
      hosts: [t3.home.lan]
networkPolicy:
  enabled: true
  ingress:
    from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx
```

`t3.publicUrl` is derived from the first host (`https://` when it has TLS). Resolve `t3.home.lan` to the ingress controller's internal IP in the DNS your VPN clients use (for example the WireGuard `DNS =` setting pointing at your LAN resolver).

Traefik: WebSockets work out of the box; raise `respondingTimeouts` on the entrypoint if long idle connections drop.

## 4. Gateway API

```yaml
route:
  enabled: true
  parentRefs:
    - name: internal-gateway
      namespace: gateway-system
      sectionName: https
  hostnames: [t3.home.lan]
```

## 5. Tailscale

Use the [Tailscale Kubernetes operator](https://tailscale.com/kb/1236/kubernetes-operator): annotate the service (`service.annotations: {tailscale.com/expose: "true"}`) or use a Tailscale ingress class. T3's own `--tailscale-serve` flag expects `tailscale` inside the container and is not used by this chart.
