# Construction Safety Backend

FastAPI + PostgreSQL backend for the AI Construction Site Safety Monitoring System.

## Prerequisites

- Python 3.11+
- Docker Desktop (for local Postgres)

## First-time setup

```bash
cd backend
py -3.12 -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
copy .env.example .env   # macOS/Linux: cp .env.example .env

# start Postgres
docker compose up -d

# apply existing migrations
alembic upgrade head

# run the API
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open http://localhost:8000/docs for Swagger UI. `GET /health` should return `{"status":"ok"}`.

Supervisors are intended to be provisioned by an admin and scoped to a site. They can log into the app, enable or disable cameras for their assigned site, and view only the enabled feeds and alerts for that site.

## AI dependencies

The backend is now configured to prefer the real YOLO detector by default. If the model file or AI dependencies are missing, the worker falls back to a no-op detector instead of fabricating random safety events.

Install only the base API stack if you want the API without live detections:

```bash
pip install -r requirements.txt
```

Install the heavier AI stack when you are ready to run the YOLO detector with a real model:

```bash
pip install -r requirements-ai.txt
```

Then set `MODEL_PATH=./model.pt` in `.env`. `DETECTOR=yolo` is already the default.

## Run everything with Docker

```bash
cd backend
docker compose up --build
```

The API is available at http://localhost:8000 and Postgres is available at `localhost:5432`.

The provided `docker compose` configuration now builds the API image with YOLO dependencies enabled. If you want to build it manually:

```bash
docker build --build-arg INSTALL_AI=true -t construction-safety-backend:ai .
```

## Push backend image to Docker Hub

```bash
cd backend
docker build -t YOUR_DOCKERHUB_USERNAME/construction-safety-backend:latest .
docker login
docker push YOUR_DOCKERHUB_USERNAME/construction-safety-backend:latest
```

Kubernetes manifests for AKS are in `backend/k8s/`. Replace placeholders in the YAML files before deploying.

## Flutter live backend config

Run the app against local Docker:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1/ --dart-define=IMAGE_BASE_URL=http://localhost:8000 --dart-define=WS_BASE_URL=ws://localhost:8000/ws --dart-define=ENABLE_MOCK_FALLBACK=false
```

Run the app against AKS after the backend service has an external URL:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_AKS_BACKEND_URL/api/v1/ --dart-define=IMAGE_BASE_URL=http://YOUR_AKS_BACKEND_URL --dart-define=WS_BASE_URL=ws://YOUR_AKS_BACKEND_URL/ws --dart-define=ENABLE_MOCK_FALLBACK=false
```

## Project layout

```
backend/
├── app/
│   ├── api/         # REST routers (auth, cameras, violations, alerts, analytics, ws)
│   ├── core/        # config, db, security (JWT + hashing)
│   ├── models/      # SQLAlchemy ORM models
│   ├── schemas/     # Pydantic request/response schemas
│   ├── workers/     # Inference worker + detector interface
│   └── main.py
├── alembic/         # DB migrations
├── docker-compose.yml  # local Postgres
└── requirements.txt
```

## Swapping in the AI model

The inference worker loads detectors from `app/workers/detectors/`. Place `model.pt` in the backend root or point `MODEL_PATH` at your trained model, then restart the backend. If the model cannot be loaded, the backend will log the issue and stop generating detections rather than inventing random ones.
