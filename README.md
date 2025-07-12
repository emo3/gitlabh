# Create helm chart that will create gitlab server with postgresql

## Use public helm chart

Main web site to find public helm charts
<https://artifacthub.io>
Main documentation from GitLab about how to use helm charts
<https://docs.gitlab.com/charts>

```sh
# add this repo to helm
helm repo add gitlab http://charts.gitlab.io/
# list current repo's
helm repo list
# my-gitlab corresponds to the release name, feel free to change it to suit your needs.
# 9.1.1 is latest helm chart version of gitlab (07/08/2025)
helm install my-gitlab gitlab/gitlab --version 9.1.1
# Generate a base64 encoded password
echo -n "YourSuperStrongPassword" | base64
kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password='WW91clN1cGVyU3Ryb25nUGFzc3dvcmQ='
# get a list of current secrets
kubectl get secrets
# what I am using, yes you need to set certmanager-issuer.email
helm install gitlab gitlab/gitlab \
  --set global.hosts.domain=localhost \
  --set global.hosts.externalIP=127.0.0.1 \
  --set global.hosts.https.enabled=false \
  --values values1.yaml \
  --set global.initialRootPassword.secret=gitlab-initial-root-password \
  --set global.initialRootPassword.key=password \
  --set certmanager-issuer.email=me@example.com
# check the status of the pods
kubectl get pods
# use the script to wait until they are all done
./wait.sh
# forward the port
kubectl port-forward svc/gitlab-webservice-default 8080:8080
# check the site
<http://localhost:8080>
The default username is "root"
# got 422 error
kubectl logs gitlab-webservice-default-674fd6dbb7-xh9m5 -c webservice --tail=500 | grep "422"
####
## if I make a mistake or need to retry
# Uninstall the GitLab Release
helm uninstall gitlab
# Verify Uninstallation
helm list
# persistent volume claims
kubectl get pvc
# use script to delete then all
./delete_pvcs.sh
# the persistent volumes
kubectl get pv
# use script to delete then all
./delete_pvs.sh
```

### issues

Error: INSTALLATION FAILED: Kubernetes cluster unreachable: Get "http://localhost:8080/version": dial tcp [::1]:8080: connect: connection refused

- Is minikube up and running?
`minikube status`

Profile "minikube" not found. Run "minikube profile list" to view all profiles.
To start a cluster, run: "minikube start"
`minikube start --driver=docker --memory=8192 --cpus=4`

Exiting due to MK_USAGE: Docker Desktop has only 7838MB memory but you specified 8192MB

```sh
minikube stop
minikube start --driver=docker --memory=8192 --cpus=4
```

### Pod(s) not in running or complete state

describe the pod(s), with the issues
`kubectl describe pod gitlab-webservice-default-674fd6dbb7-7h727`
Verify the available memory on the nodes in your cluster.
`kubectl describe nodes`

```text
Increase Docker Desktop Memory Limit:
  Open Docker Desktop.
  Go to Settings (or Preferences on macOS).
  Navigate to the Resources section.
  Adjust the Memory slider to allocate more memory (e.g., set it to 8192 MB or higher).
  Click Apply & Restart to save the changes.
Make sure you do NOT use the maximum values, this will cause other issues!
```

Error: INSTALLATION FAILED: execution error at (gitlab/charts/certmanager-issuer/templates/cert-manager.yml:14:3): You must provide an email to associate with your TLS certificates. Please set certmanager-issuer.email

- Make sure you have "--set certmanager-issuer.email=me@example.com", in your helm install cmd

## Use my version of helm chart

### Start Minikube with the Docker Driver

This will allow you run minikube without elevated permissions

`minikube start --driver=docker`

If you encounter permission issues with Docker, you may need to add your user to the Docker group. You can do this with the following command:

```sh
sudo usermod -aG docker $USER
```

After running this command, log out and log back in for the changes to take effect.

### Verify all is well with code

```sh
# Make sure all is well with all helm templates
helm template . --debug
# Make sure you do not have any lint issues
helm lint .
# Check to make sure config is set correctly
kubectl config current-context
# If not set to minikube, set it
kubectl config use-context minikube
```

## Initialize helm directory

```sh
cd ~/code/cookbooks
helm create gitlabh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/postgresql --versions
helm dependency build
```

See the following for more information
<https://gitlab-com.gitlab.io/support/toolbox/upgrade-path>
If using Enterprise edition
<https://hub.docker.com/r/gitlab/gitlab-ee/tags>
If using Community edition
<https://hub.docker.com/r/gitlab/gitlab-ce/tags>

## Run Container

```sh
helm upgrade --install gitlab . --dry-run --debug
helm upgrade --install gitlab . --debug
kubectl wait pod gitlab-845c7769d6-q6nlq --for=condition=ready --timeout=60s

```

### Verify everything is running

`kubectl get pods`
<http://locahost:8080>

# Find your running GitLab pod name (it will be different from the example)
export POD_NAME=$(kubectl get pods -l "app=gitlab" -o jsonpath="{.items[0].metadata.name}")
echo "Your GitLab pod is: $POD_NAME"

kubectl logs -f $POD_NAME

# Forward local port 8080 to the pod's port 80
kubectl port-forward $POD_NAME 8080:80

## more debugging

kubectl exec -it $POD_NAME -- gitlab-rails console

if issues, fix them
`helm uninstall gitlab`
kubectl delete all --all -n default

## Ingress Configuration

All ingress settings are managed under the `gitlab.ingress` section in `values.yaml`.  
To customize ingress (host, TLS, annotations, etc.), edit the following block:

```yaml
gitlab:
  ingress:
    enabled: true
    path: /
    pathType: Prefix
    annotations:
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    tls:
      enabled: true
      secretName: gitlab-tls
    hosts:
      - host: your-domain.example.com
        paths:
          - path: /
```

- **enabled**: Set to `true` to enable ingress.
- **hosts**: Replace `your-domain.example.com` with your domain.
- **tls**: Set up your TLS secret as needed.

> **Note:** There is no `global.ingress` block. All ingress configuration must be done under `gitlab.ingress`.
