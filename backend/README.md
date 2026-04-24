# Construction Safety Backend

FastAPI + PostgreSQL backend for the AI Construction Site Safety Monitoring System.

## Prerequisites

- Python 3.11+
- Docker Desktop (for local Postgres)

## First-time setup

```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env     # Windows: copy .env.example .env

# start Postgres
docker compose up -d

# create initial migration + apply
alembic revision --autogenerate -m "init schema"
alembic upgrade head

# run the API
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open http://localhost:8000/docs for Swagger UI. `GET /health` should return `{"status":"ok"}`.

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

The inference worker loads detectors from `app/workers/detectors/`. Ship default `MockDetector` today; when `model.pt` arrives, set `DETECTOR=yolo` and `MODEL_PATH=./model.pt` in `.env` and restart.
