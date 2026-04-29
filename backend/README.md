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

## AI dependencies are optional

The backend runs with the default `MockDetector` and does not need YOLO or Torch for basic app testing.

Install only the base API stack:

```bash
pip install -r requirements.txt
```

Install the heavier AI stack only when you are ready to run the YOLO detector with a real model:

```bash
pip install -r requirements-ai.txt
```

Then set `DETECTOR=yolo` and `MODEL_PATH=./model.pt` in `.env`.

## Run everything with Docker

```bash
cd backend
docker compose up --build
```

The API is available at http://localhost:8000 and Postgres is available at `localhost:5432`.

If you want the Docker image to include YOLO dependencies too, build with:

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

The inference worker loads detectors from `app/workers/detectors/`. The default setup uses `MockDetector`, which is enough for end-to-end app testing. When `model.pt` arrives, install `requirements-ai.txt`, set `DETECTOR=yolo` and `MODEL_PATH=./model.pt` in `.env`, then restart the backend.
