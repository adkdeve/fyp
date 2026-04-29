# AKS deployment

Replace `YOUR_DOCKERHUB_USERNAME` in `03-backend.yaml` before applying these files.

## Build and push backend image

```bash
cd backend
docker build -t YOUR_DOCKERHUB_USERNAME/construction-safety-backend:latest .
docker login
docker push YOUR_DOCKERHUB_USERNAME/construction-safety-backend:latest
```

## Deploy to AKS

```bash
az aks get-credentials --resource-group YOUR_RESOURCE_GROUP --name YOUR_AKS_CLUSTER
kubectl apply -f k8s/
kubectl get pods -n construction-safety
kubectl get svc backend -n construction-safety
```

The backend live URL is the external IP shown for the `backend` LoadBalancer service. Use:

```bash
http://EXTERNAL-IP/health
```

## Production notes

- Change every placeholder in `01-secret.yaml`.
- Change `CORS_ORIGINS` in `03-backend.yaml` to the real frontend URL.
- Set `DETECTOR=yolo` only when the image contains `/app/model.pt` or you mount the model into the pod.
