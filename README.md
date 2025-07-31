# 🛠️ Local GitLab Setup with Minikube + Helm

This project sets up a **fully functional local GitLab instance** using:

* ✅ Minikube (Kubernetes)
* ✅ GitLab Helm chart
* ✅ Built-in nginx ingress controller
* ✅ `gitlab.localhost` domain
* ✅ Self-signed HTTPS
* ✅ Automation scripts

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

### 1. Update Configuration File, if needed

[minimal-values.yaml](./minimal-values.yaml)
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

* Install GitLab using Helm and your config
* Wait for all GitLab pods to be ready
* Create any needed dummy secrets (e.g., for backups)
* Start port-forwarding
* Print access URLs and login credentials

---

### 3. Access GitLab

After install, visit the URL shown in terminal, e.g.:

```text
https://gitlab.localhost:PORT
```

Accept any browser warnings about the self-signed certificate.

---

### 4. Get Root Password

```sh
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode && echo
```

* **Username**: `root`
* **Password**: (shown above or printed by install script)

---

## 🧪 Troubleshooting

### Basic Diagnostic

```bash
./verify-gitlab.sh
```

This script checks:

* Pod health
* Ingress setup
* DNS resolution
* Port-forward status

---

### Check pod status

```sh
kubectl get pods -n gitlab
```

You should see most pods in `Running` or `Completed` status.
The `gitlab-runner` pod may crash — this is expected and non-critical.

---

### Manually View Ingress

```sh
kubectl get ingress -n gitlab
```

Should show `gitlab.localhost` as the host.

---

### Manually Port Forward (if needed)

```sh
kubectl port-forward -n gitlab svc/gitlab-webservice-default 8080:80
```

Then access: `http://gitlab.localhost:8080`

---

## 🧼 Cleanup

### Using Script (Recommended)

```sh
./cleanup-gitlab.sh
```

This will:

* Uninstall the Helm release
* Delete the `gitlab` namespace
* Remove host file entries
* Stop background port-forward

---

### Manual Cleanup

```sh
helm uninstall gitlab -n gitlab
kubectl delete namespace gitlab
minikube delete
```

Remove host entry:

```sh
sudo sed -i '' '/gitlab.localhost/d' /etc/hosts'  # macOS
```

Or:

```sh
sudo sed -i '/gitlab.localhost/d' /etc/hosts'     # Linux
```

---

## 📁 Project Structure

| File                  | Description                                 |
| --------------------- | ------------------------------------------- |
| `check-gitlab.sh`     | Checks and installs prerequisites           |
| `install-gitlab.sh`   | Installs GitLab and starts port forwarding  |
| `verify-gitlab.sh`    | Performs health checks and diagnostics      |
| `cleanup-gitlab.sh`   | Deletes GitLab install and cleans resources |
| `minimal-values.yaml` | Helm values for minimal GitLab deployment   |

---

## 🧠 Key Features

* 🔧 Automated setup for repeatable local GitLab installs
* 🌐 Uses `gitlab.localhost` and dynamic ports via `minikube service`
* 🔐 Self-signed TLS for HTTPS access
* 💻 No external cloud or DNS needed
* 🧪 Debug scripts and clean teardown process
* 📁 Uses the official GitLab Helm chart

---

## 🧠 Notes

* `minimal-values.yaml` is required before installation
* HTTPS port may change between restarts
* Accept TLS warnings in your browser
* `gitlab-runner` is disabled for simplicity
* This setup is for local testing only — not production

---

## 📚 References

* [GitLab Helm Charts](https://docs.gitlab.com/charts/)
* [Minikube Docs](https://minikube.sigs.k8s.io/)
* [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
