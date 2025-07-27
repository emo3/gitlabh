
# 🛠️ Local GitLab Setup with Minikube + Helm + Caddy

This guide sets up a **fully functional GitLab instance** on your local machine using:

- Minikube (Kubernetes)
- Helm chart (`gitlab-local-values.yaml`)
- Self-signed TLS via `cert-manager`
- Domain: `https://gitlab.example.com`
- Caddy reverse proxy to handle TLS and routing

---

## 📦 Prerequisites

- Docker
- Minikube
- kubectl
- Helm
- Caddy (for reverse proxy)
- Linux (tested on AlmaLinux 8)

---

## 🚀 Quick Start

### 1. Start Minikube

```sh
minikube start --memory=8192 --cpus=4 --driver=docker
```

> ❗ If the cluster already exists, you can't change CPU/memory. Use `minikube delete` to recreate if needed.

---

### 2. Add GitLab Helm Repo

```sh
helm repo add gitlab https://charts.gitlab.io/
helm repo update
```

---

### 3. Create Namespace

```sh
kubectl create namespace gitlab
```

---

### 4. Install GitLab with Helm

Make sure `gitlab-local-values.yaml` is in your current directory.

```sh
helm upgrade --install gitlab gitlab/gitlab   -n gitlab   -f gitlab-local-values.yaml
```

> This deploys GitLab with minimal resources, self-signed certs, and disables non-essential services.

---

### 5. Add Host Entry

Edit your `/etc/hosts`:

```sh
echo "127.0.0.1 gitlab.example.com" | sudo tee -a /etc/hosts
```

---

### 6. Get Minikube IP

```sh
minikube ip
```

Example: `192.168.49.2`

---

### 7. Configure Caddy Reverse Proxy

Install Caddy:

```sh
sudo dnf install caddy   # or use: curl -sSL https://get.caddyserver.com | bash
```

Create `Caddyfile`:

```code
gitlab.example.com:443 {
    reverse_proxy https://<MINIKUBE_IP>:32623 {
        header_up Host gitlab.example.com
        transport http {
            tls_insecure_skip_verify
        }
    }

    tls internal
}
```

Replace `<MINIKUBE_IP>` with the result from step 6.

Start Caddy:

```sh
sudo caddy run --config Caddyfile
```

---

### 8. Access GitLab

Open your browser and go to:

```code
https://gitlab.example.com
```

> You’ll see a self-signed TLS warning — click **Advanced → Proceed**.

---

## 🔑 Default Credentials

- **Username**: `root`
- **Password**: as set in your `gitlab-local-values.yaml`:

```code
initialRootPassword:
  password: 'YourInsecureTestPasswordHere'
```

If you forgot it, retrieve from Kubernetes:

```sh
kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -ojsonpath="{.data.password}" | base64 --decode
```

---

## 🧪 Troubleshooting

### 1. GitLab not accessible?

- Check `kubectl get pods -n gitlab` — all pods should be `Running` or `Completed`
- Use `kubectl port-forward` to test access:

  ```sh
  kubectl port-forward -n gitlab svc/gitlab-nginx-ingress-controller 8443:443
  curl -k https://localhost:8443 -H "Host: gitlab.example.com"
  ```

### 2. Caddy not working?

- Ensure Minikube IP and port `32623` are correct
- Run: `kubectl get svc -n gitlab gitlab-nginx-ingress-controller` to confirm NodePort

---

## 🧼 Cleanup

```sh
helm uninstall gitlab -n gitlab
kubectl delete namespace gitlab
minikube delete
sudo pkill caddy
```

---

## 📚 References

- [GitLab Helm Charts](https://docs.gitlab.com/charts/)
- [Minikube Docs](https://minikube.sigs.k8s.io/)
- [Caddy Server](https://caddyserver.com/)
