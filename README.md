# StartTech Application

Go backend, React frontend, Kubernetes manifests, and the CI/CD pipelines that ship them — the app half of the StartTech assessment.

## Backend

Go/Gin API, pulled from [Innocent9712/much-to-do](https://github.com/Innocent9712/much-to-do) (`feature/full-stack` branch) and adapted for this project. MongoDB for persistence, Redis for session caching, JWT auth.

Every route sits under `/api/v1` now — health, auth, tasks, users. The upstream repo mounted everything at root; that changed here so it lines up with how CloudFront routes `/api/*` to the backend ALB.

A few things worth knowing if you're reading the code:

The env var is `REDIS_HOST`, not `REDIS_ADDR` like upstream had it. The spec names it explicitly, so it got renamed.

If Redis is down when a pod starts, the app logs it and keeps running on a no-op cache. A missing or bad `MONGO_URI` still kills the process — Mongo's the real datastore, there's no fallback that makes sense there.

Logs are structured JSON to stdout, which is what Container Insights and FluentBit expect.

Health lives at `/api/v1/health`, checks both Mongo and Redis when caching's on, returns 503 if either's down.

## Frontend

React, Vite, TypeScript — same upstream source, adapted the same way. API calls go through a shared `apiClient` (axios) with a relative base URL by default. In production that means it just calls whatever origin served the page. No hardcoded domain, no mixed-content issues once it's behind CloudFront.

## Kubernetes

Three manifests, all in `k8s/`.

`deployment.yaml` uses RollingUpdate with maxSurge 1 and maxUnavailable 0, so a bad rollout doesn't drop capacity while it's happening. Secrets (`REDIS_HOST`, `MONGO_URI`, `JWT_SECRET_KEY`) come from a Kubernetes secret rather than being written into the file.

`service.yaml` is ClusterIP on port 8080.

`ingress.yaml` uses the ALB ingress class — this is what actually triggers the AWS Load Balancer Controller to provision the load balancer.

The secret has to exist before any of this works:

```bash
kubectl create secret generic backend-secrets \
  --from-literal=REDIS_HOST=<your-redis-endpoint> \
  --from-literal=MONGO_URI=<your-mongo-uri> \
  --from-literal=JWT_SECRET_KEY=<your-secret>
```

## CI/CD

Two workflows, both in `.github/workflows/`.

`backend-ci-cd.yml` triggers on changes to `backend/` or `k8s/`: Go tests, Docker build tagged by commit SHA, a Trivy scan, push to ECR, patch the image tag into `deployment.yaml`, apply to the cluster.

`frontend-ci-cd.yml` triggers on changes to `frontend/`: `npm ci`, `npm audit`, build, sync to S3, invalidate CloudFront.

Both need repo secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and for the frontend pipeline, `FRONTEND_BUCKET_NAME` and `CLOUDFRONT_DISTRIBUTION_ID` — both come from the infra repo's Terraform outputs.

## Scripts

Five, in `scripts/`, mostly the manual version of what the pipelines already automate.

`deploy-backend.sh` builds, pushes, deploys — same steps the backend pipeline runs.

`deploy-frontend.sh` builds, syncs, invalidates — same as the frontend pipeline.

`health-check.sh` hits the frontend, the `/api/v1/health` endpoint, and a fake client-side route through CloudFront, to confirm the SPA fallback and the API routing are both actually working.

`rollback.sh` reverts to the previous deployment revision if something ships broken.

## Related repository

Infrastructure — VPC, EKS, S3, CloudFront, Redis — lives in [`starttech-infra`](https://github.com/Reallife-1/starttech-infra).