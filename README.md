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
