# Add to your terminal alias:
1. Enable Docker backend for minikube: `alias minidocker="eval \$(minikube docker-env); eval \$(minikube -p minikube docker-env)"`
2. Revert changes back to docker after stopping minikube: `alias hostdocker="unset DOCKER_HOST DOCKER_TLS_VERIFY DOCKER_CERT_PATH"`

# Run docker compose with existing docker files
1. Change in `./nginx/nginx.conf` the line with *proxy_pass* from `proxy_pass http://flask-service:${PORT};` to `proxy_pass http://flask_app:${PORT};` in order to make it work only on Docker.

# Run with minikube backed by Docker
1. Check if Docker is running. If not start Docker or Docker Desktop.
2. Start minikube by using following command: `minikube start`. This will start only 1 node only.
3. Use command `minidocker` to enable docker backend for minikube.
4. Build docker images using `docker_build.sh` script.
5. Apply Kubernetes YAML files using `kubernetes_apply.sh` script.

# Cleaning images and fresh rebuild
1. Run `docker_build.sh` script with argument `-c` for cleaning the images or `-r` to clean and rebuild fresh.
2. Run `kubernetes_apply.sh` script with argument `-c` for cleaning the images or `-r` to clean and rebuild fresh.

# Access minikube on docker
1. Make a port forward to the docker using `kubectl port-forward <pod_name> 80`.
2. Expose the service using `kubectl expose`.

# Deployment
## Blue/Green
1. Apply with `./kubernetes_apply.sh` first deployment.
2. Apply 2nd deployment using `kubectl -f apply web_server/deployment/app-deployment-green.yaml`
3. Edit the service `kubectl edit services flask-deployment` and change the version to `green`, to point to 2nd deployment.
4. Use `kubectl port-forward` to verify it works.
5. And magically it should use the 2nd deployment. After everything works, change the public service to point to the `green deployment`.

## Canary
*TODO*

# Rolling update
1. Build 2 docker images using `docker_build.sh` with `--nginx-tag v1.0` and `--nginx-tag v2.0`.
2. Change in `kubernetes_apply.sh` line with `app-deployment.yaml` to `app-deployment-rolling-update.yaml`. This is just changing the image pull version and strategy to update.
3. Use command `kubectl set image deployment/flask-deployment flask-app=flask_app:v2.0` to change to v2.0.
4. To see the status use command `kubectl rollout status deployment/flask-deployment`.
5. To Rollback use command `kubectl rollout undo deployment/flask-deployment`.
6. To view history use command `kubectl rollout history deployment/flask-deployment --revision=2`.

# Connect to minikube
1. Use command `minikube sh` in order to connect to Docker container that runs minikube. 
2. Use `ls /etc/kubernetes/manifest` to see everything that Kubernetes have.
3. You can also use `kubectl proxy 8001` and then curl to that to see all the groups and APIs.

# View Kubernetes dashboard
1. Enable Metrics Addon using the following command `minikube addons enable metrics-server`.
2. Start Dashboard using this command `minikube dashboard`.

# View logs
1. View logs from a pod: `kubectl logs <pod_name>`.
2. View logs from a pod on a specific container: `kubectl logs <pod_name> -c <container_name>`.
3. Stream logs to console: `kubectl logs -f <pod_name>`.
4. Get last 20 logs: `kubectl logs --tail=20 <pod_name>`.
5. Get last 10 seconds of logs: `kubectl logs --since=10s <pod_name>`.
6. Get logs from pods with specific label: `kubectl logs -l app=backend --all-containers=true`.

# Debug commands:
1. Get pod as YAML file: `kubectl get pod <pod_name> -o yaml`.
2. Describe pod details: `kubectl describe pod <pod_name>`.
3. Get deployment: `kubectl get deployment <deployment_name> -o wide`.
4. Create a debug copy of the app: `kubectl debug myapp --it --copy-to=myapp-debug --container=myapp -sh`.
5. Connect to a pod: `kubectl exec <pod_name> -it -- sh`.

# RBAC:
1. Follow this [Link](https://blog.kubesimplify.com/kubernetes-access-control-with-authentication-authorization-admission-control).
2. Files in *./rbac* folder, are using development instead of marketing.
3. *role.yaml* and *role-binding.yaml* are used for user to have permission to use *kubectl*.
4. *role-service-account.yaml* and *role-binding-service-account.yaml* are used for kubelet to have permission to create execute commands, like cURL.
5. Security Context can be set at level of pod (all containers inside pod will inherit), or it can be set at container level and overrides the pod, but it won't exceed the baseline (the maximum level of security from the pod).

# Resource Quotas
Those are tied to namespace level. Ex: namespace dev, when used, it can limit everything, like max pods. This is an admission controller.

# Ingress & Egress
1. By default, in minikube network policies do **NOT** work! You have to enable them manually when minikube starts by using this command `minikube start --network-plugin=cni --cni=calico`.
2. If some of your pods work with DNS resolutions and you block everything in egress, it won't work. For example flask app it cannot start because init container will try to connect to mongodb-service on port 27017. To make it work, you have to allow egress to port 53, with pod selector kube-dns, and in namespace kube-system.
3. For controllers, you need to use `minikube addons enable ingress`.
4. To test from the browser, you need to use `minikube tunnel` in order to make a tunnel from host to docker.
5. After creating the tunnel, you can resolve the URL or you can add it to `/etc/hosts` like this: `127.0.0.1 example.cafe.com`.

## Ingress & Ingress Controller
Follow this [Link](https://kubernetes.io/docs/tasks/access-application-cluster/ingress-minikube/)

## Gateway & Gateway API
Follow this [Link](https://blog.nashtechglobal.com/hands-on-kubernetes-gateway-api-with-nginx-gateway-fabric/)
