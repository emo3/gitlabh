# Create helm chart that will create gitlab server with postgresql

## Initialize helm directory

```sh
cd ~/code/cookbooks
helm create gitlabh
```

See the following for more information
<https://gitlab-com.gitlab.io/support/toolbox/upgrade-path>
<https://hub.docker.com/r/gitlab/gitlab-ee/tags>

## Start Minikube with the Docker Driver

This will allow you run minikube without elevated permissions

`minikube start --driver=docker`

## Run Container

### Verify all is well with code

```sh
helm template . --debug
helm lint .
kubectl config current-context
kubectl config use-context docker-desktop
```

### run the code

```sh
helm install gitlab . --dry-run --debug
helm install gitlab . --debug
```

### Verify everything is running

`kubectl get pods`

if issues, fix them
`helm uninstall gitlab`
