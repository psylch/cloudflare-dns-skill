# Kubernetes & Azure Integration

## External-DNS Integration

### Kubernetes Secret

```bash
kubectl create namespace external-dns

kubectl create secret generic cloudflare-api-token \
  --namespace external-dns \
  --from-literal=cloudflare_api_token="$CF_API_TOKEN"
```

### Helm Values (kubernetes-sigs/external-dns)

```yaml
fullnameOverride: external-dns

provider:
  name: cloudflare

env:
  - name: CF_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: cloudflare_api_token

extraArgs:
  cloudflare-proxied: true
  cloudflare-dns-records-per-page: 5000

sources:
  - service
  - ingress

domainFilters:
  - example.com

txtOwnerId: "aks-cluster-name"  # MUST be unique per cluster
txtPrefix: "_externaldns."
policy: upsert-only  # Production: NEVER use sync
interval: "5m"

logLevel: info
logFormat: json

resources:
  requests:
    memory: "64Mi"
    cpu: "25m"
  limits:
    memory: "128Mi"

serviceMonitor:
  enabled: true
  interval: 30s
```

### Ingress Annotations

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "app.example.com"
    external-dns.alpha.kubernetes.io/ttl: "300"
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
```

### External-DNS Logs

```bash
kubectl logs -n external-dns deployment/external-dns -f
kubectl logs -n external-dns deployment/external-dns | grep -i cloudflare
kubectl logs -n external-dns deployment/external-dns | grep -i "All records are already up to date"
```

## cert-manager with Cloudflare DNS-01

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cloudflare
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-cloudflare-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
        selector:
          dnsZones:
            - example.com
```

## AKS Ingress Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-cloudflare
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

## Token Rotation

```bash
# 1. Create new token in Cloudflare dashboard

# 2. Update Kubernetes secret
kubectl create secret generic cloudflare-api-token \
  --namespace external-dns \
  --from-literal=cloudflare_api_token="NEW_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Restart External-DNS
kubectl rollout restart deployment external-dns -n external-dns

# 4. Verify
kubectl logs -n external-dns deployment/external-dns | head -20

# 5. Revoke old token in Cloudflare dashboard
```

## Rate Limit Mitigation

```yaml
extraArgs:
  cloudflare-dns-records-per-page: 5000
  zone-id-filter: "specific-zone-id"

interval: "10m"
```
