# Create helm chart that will create gitlab server with postgresql

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

## Start Minikube with the Docker Driver

This will allow you run minikube without elevated permissions

`minikube start --driver=docker`

If you encounter permission issues with Docker, you may need to add your user to the Docker group. You can do this with the following command:

```sh
sudo usermod -aG docker $USER
```

After running this command, log out and log back in for the changes to take effect.

## Verify all is well with code

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
