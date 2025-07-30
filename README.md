# 🛠️ Local GitLab Setup with Minikube + Helm

This guide sets up a **fully functional GitLab instance** on your local machine using:

- Minikube (Kubernetes)
- Helm chart with minimal configuration
- Built-in nginx ingress controller
- Domain: `https://gitlab.localhost`
- Self-signed certificates
- **Automated setup scripts**

---

## 📦 Prerequisites

- Docker
- Minikube
- kubectl  
- Helm
- macOS/Linux

> **Note:** The setup scripts will automatically install missing prerequisites where possible.

---

## 🚀 Quick Start (Automated)

### 1. Create Configuration File

First, create the required `minimal-values.yaml` configuration file in your project directory:

```yaml
global:
  edition: ce
  hosts:
    domain: localhost
    externalIP: 192.168.49.2 
    https: false
  ingress:
    configureCertmanager: false
    class: nginx
    annotations: {}

nginx-ingress:
  enabled: true
  controller:
    service:
      type: NodePort

gitlab:
  webservice:
    replicas: 1

redis:
  install: true

postgresql:
  install: true
```

> **Note:** You may need to update the `externalIP` to match your minikube IP (get it with `minikube ip`).

### 2. Check Prerequisites & Setup Environment

```sh
./check-gitlab.sh
```

This script will:

- Install missing dependencies (Docker, Minikube, kubectl, Helm)
- Start Docker and Minikube if needed
- Create the GitLab namespace
- Set up Helm repositories
- Verify your configuration file exists

### 3. Install GitLab

```sh
./install-gitlab.sh
```

This script will:

- Install GitLab using Helm
- Wait for all pods to be ready
- Configure host mapping
- Retrieve login credentials
- Provide access instructions

### 4. Access GitLab

Follow the instructions provided by the install script to access GitLab in your browser.

---

## 🚀 Manual Setup (Alternative)

### 1. Start Minikube

```sh
minikube start --memory=8192 --cpus=4 --driver=docker
```

> ❗ If the cluster already exists, you can't change CPU/memory. Use `minikube delete` to recreate if needed.

### 2. Add GitLab Helm Repo

```sh
helm repo add gitlab https://charts.gitlab.io/
helm repo update
```

### 3. Create Namespace

```sh
kubectl create namespace gitlab
```

### 4. Install GitLab with Helm

Make sure `minimal-values.yaml` is in your current directory.

```sh
helm upgrade --install gitlab gitlab/gitlab -n gitlab -f minimal-values.yaml --timeout 10m
```

### 5. Wait for Deployment

Monitor the deployment (this can take 5-15 minutes):

```sh
kubectl get pods -n gitlab
```

All pods should show `Running` or `Completed` status.

> **Note:** The `gitlab-runner` pod may show `CrashLoopBackOff` - this is not critical for basic GitLab functionality.

### 6. Get Service Access URL

Start the minikube service tunnel (keep this terminal open):

```sh
minikube service gitlab-nginx-ingress-controller -n gitlab --url
```

This will output URLs like:

```text
http://127.0.0.1:55707
http://127.0.0.1:55708  # <- Use this HTTPS port
http://127.0.0.1:55709
```

### 7. Add Host Entry

Add the domain to your hosts file:

```sh
echo "127.0.0.1 gitlab.localhost" | sudo tee -a /etc/hosts
```

### 8. Access GitLab

Open your browser and go to:

```text
https://gitlab.localhost:55708
```

> Replace `55708` with your actual HTTPS port from step 6.
> You'll see a self-signed TLS warning — click **Advanced → Proceed**.

---

## 🔑 Default Credentials

### Get Root Password

```sh
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode && echo
```

### Login

- **Username**: `root`
- **Password**: (from command above or displayed by install script)

---

## 🧪 Troubleshooting

### 1. Connection timeout or 404 errors?

- Ensure minikube service tunnel is running:

  ```sh
  minikube service gitlab-nginx-ingress-controller -n gitlab --url
  ```

- Use the correct host header:

  ```sh
  curl -I -H "Host: gitlab.localhost" -k https://127.0.0.1:YOUR_HTTPS_PORT
  ```

### 2. Check pod status

```sh
kubectl get pods -n gitlab
```

All important pods should be `Running`. The `gitlab-runner` pod may crash - this is not critical.

### 3. View ingress configuration

```sh
kubectl get ingress -n gitlab
```

Should show `gitlab.localhost` as the host.

### 4. Alternative access method (port-forward)

```sh
kubectl port-forward -n gitlab svc/gitlab-webservice-default 8080:8080
```

Then access: `http://localhost:8080`

### 5. Reset everything

```sh
./cleanup-gitlab.sh
```

Then start over with creating `minimal-values.yaml` and running `./check-gitlab.sh`

---

## 📁 Project Files

This setup includes the following scripts and configuration files:

### Scripts

- **`check-gitlab.sh`** - Verifies prerequisites and sets up environment
- **`install-gitlab.sh`** - Installs GitLab and configures access  
- **`cleanup-gitlab.sh`** - Removes GitLab installation and resources
- **`verify-gitlab.sh`** - Diagnostic script for troubleshooting connectivity

### Configuration

- **`minimal-values.yaml`** - Helm values for GitLab installation (you must create this)

### Usage

```sh
# Create minimal-values.yaml first (see sample above)

# Full setup
./check-gitlab.sh
./install-gitlab.sh

# Cleanup when done
./cleanup-gitlab.sh

# Troubleshooting
./verify-gitlab.sh
```

---

## 🧼 Cleanup

### Using Script (Recommended)

```sh
./cleanup-gitlab.sh
```

### Manual Cleanup

```sh
helm uninstall gitlab -n gitlab
kubectl delete namespace gitlab
minikube delete
```

Remove host entry:

```sh
sudo sed -i '/gitlab.localhost/d' /etc/hosts
```

---

## 📚 Key Features of This Setup

- **Automated setup scripts** for easy installation and cleanup
- **Prerequisite checking** with automatic installation where possible
- Uses minikube service tunneling instead of external reverse proxy
- No external dependencies - built-in nginx ingress handles routing  
- Domain is `gitlab.localhost` with dynamic HTTPS ports
- **Comprehensive error handling** and troubleshooting guidance
- Simple configuration with minimal resource requirements

---

## ⚠️ Important Notes

- **You must create `minimal-values.yaml` before running the scripts**
- Keep the `minikube service` terminal open while using GitLab
- The HTTPS port number changes each time you restart the service tunnel
- This setup is for local development only
- Self-signed certificates will trigger browser warnings

---

## 📚 References

- [GitLab Helm Charts](https://docs.gitlab.com/charts/)
- [Minikube Docs](https://minikube.sigs.k8s.io/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
