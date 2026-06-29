# Construction Safety AI Monitoring System

**Final Year Project (FYP) -- COMSATS University Islamabad, Lahore Campus**
**Department of Computer Science**

---

## Project Information

| Field | Details |
|---|---|
| **Project Title** | Construction Safety AI Monitoring System |
| **Group ID** | *(Add your group ID here, e.g., SP22-BSE-000)* |
| **Session** | FA22 |
| **Supervisor** | *(Add supervisor name)* |
| **Co-Supervisor** | *(Add co-supervisor name, if applicable)* |

### Team Members

| Name | Registration No. | Role |
|---|---|---|
| Muhammad Ali | *(Add reg. no.)* | Full-Stack & AI Developer |
| *(Add member)* | *(Add reg. no.)* | *(Add role)* |
| *(Add member)* | *(Add reg. no.)* | *(Add role)* |

---

## Abstract

Construction sites are inherently hazardous environments where safety violations can lead to severe injuries or fatalities. This project presents an **AI-powered real-time construction safety monitoring system** that leverages deep learning models (YOLOv8) to detect safety violations including missing PPE (helmets, vests, gloves, boots, masks), fire/smoke hazards, and unauthorized zone entries. The system provides real-time alerts to safety officers through a cross-platform mobile application and a web-based admin dashboard, enabling immediate corrective action. The architecture follows a distributed microservices design with a Flutter mobile app, a FastAPI backend server, a dedicated ML inference service, and a React admin dashboard -- all integrated with Firebase for real-time data synchronization.

---

## Problem Statement

Construction industry workers face significant safety risks due to non-compliance with Personal Protective Equipment (PPE) regulations and exposure to fire/smoke hazards. Manual safety monitoring is inconsistent, labor-intensive, and error-prone. There is a need for an automated, intelligent system that can continuously monitor construction sites via CCTV cameras, detect safety violations in real-time, and immediately notify responsible safety officers to take corrective action.

---

## Objectives

1. Develop AI models using YOLOv8 for real-time detection of PPE violations (helmet, vest, gloves, boots, mask) and fire/smoke hazards.
2. Build a distributed backend system capable of processing live RTSP camera feeds and running inference at near real-time speeds.
3. Create a cross-platform mobile application for safety officers to receive real-time alerts, view live camera feeds, and manage violations.
4. Develop a web-based admin dashboard for site management, camera configuration, and analytics.
5. Implement safe zone enforcement using geofencing with polygon-based restricted area detection.
6. Ensure the system supports multi-site deployment with role-based access control.

---

## Features

### AI & Detection
- Real-time PPE violation detection (no helmet, no vest, no gloves, no boots, no mask, unsafe material)
- Fire and smoke detection using custom-trained YOLOv8 model
- Safe zone enforcement with polygon-based restricted area monitoring
- Intelligent PPE grouping by person using IoU (Intersection over Union) matching
- 24-hour violation cooldown to prevent duplicate alerts per person
- Configurable detection confidence thresholds

### Mobile Application (Flutter)
- Real-time violation alerts via WebSocket with push notifications
- Live annotated MJPEG camera feed streaming
- Violation history with filtering and search
- Analytics dashboard with violation trend charts
- Camera management (enable/disable, RTSP configuration)
- Safe zone drawing on interactive maps
- Dark mode and localization support
- Offline capability with cached data

### Web Admin Dashboard (React)
- Multi-site and multi-camera management
- Supervisor and safety officer account management
- Live video stream viewer with AI overlay controls
- Interactive safe zone drawing on canvas
- Real-time violation feed and analytics
- Role-based access (Admin vs. Site Supervisor/Officer)

### Backend & Infrastructure
- RESTful API with JWT authentication and token refresh
- Real-time WebSocket communication for instant alerts
- Firebase Firestore for real-time database synchronization
- Firebase Cloud Storage for violation snapshot images
- Separate ML microservice for scalable inference

---

## System Architecture

```
+-------------------+       +-------------------+       +---------------------+
|   Flutter Mobile  | <---> |   FastAPI Backend  | <---> |  ML Inference API   |
|   App (Dart)      |  REST |   (Python 3.11+)  |  HTTP |  (FastAPI + YOLO)   |
|   Port: Device    |  & WS |   Port: 8000      |       |  Port: 8001         |
+-------------------+       +-------------------+       +---------------------+
        |                           |                            |
        |                           v                            |
        |                   +---------------+                    |
        |                   |   Firebase    |                    |
        +-----------------> |  - Firestore  | <------------------+
                            |  - Storage    |
        +-----------------> |  - Auth       |
        |                   +---------------+
        |
+-------------------+
|  React Web Admin  |
|  Dashboard (TS)   |
|  Port: 5173       |
+-------------------+
```

### Component Overview

| Component | Technology | Purpose |
|---|---|---|
| Mobile App | Flutter 3.x + GetX | Safety officer interface for alerts and monitoring |
| Backend API | FastAPI + Uvicorn | REST API, WebSocket server, camera worker management |
| ML Inference | FastAPI + YOLOv8 + PyTorch | Object detection and safety violation inference |
| Web Dashboard | React 18 + TypeScript + Vite | Admin panel for site/camera/user management |
| Database | Firebase Firestore | Real-time NoSQL database for all persistent data |
| File Storage | Firebase Cloud Storage | Violation snapshot images |
| Authentication | JWT (python-jose + bcrypt) | Token-based auth with secure storage on mobile |

---

## Technologies Used

### Mobile Application
| Technology | Version | Purpose |
|---|---|---|
| Flutter | 3.x | Cross-platform mobile framework |
| Dart | 3.x | Programming language |
| GetX | 4.7.2 | State management, routing, DI |
| Firebase SDK | Latest | Firestore, Auth, Storage, Messaging |
| flutter_secure_storage | Latest | Encrypted credential storage |
| flutter_map + latlong2 | Latest | Map-based safe zone visualization |
| fl_chart | Latest | Analytics charts |
| web_socket_channel | Latest | Real-time violation streams |

### Backend API
| Technology | Version | Purpose |
|---|---|---|
| Python | 3.11+ | Programming language |
| FastAPI | 0.115.0 | Async REST API framework |
| Uvicorn | Latest | ASGI server |
| firebase-admin | 6.2.0+ | Firestore & Cloud Storage access |
| OpenCV | Latest | Frame processing and annotation |
| python-jose | Latest | JWT token handling |
| bcrypt | Latest | Password hashing |
| Pydantic | Latest | Request/response validation |

### ML Inference Service
| Technology | Version | Purpose |
|---|---|---|
| YOLOv8 (Ultralytics) | 8.3.0 | Object detection framework |
| PyTorch | 2.4.1+ | Deep learning engine |
| OpenCV | Latest | Image preprocessing |
| FastAPI | Latest | Inference API server |

### Web Admin Dashboard
| Technology | Version | Purpose |
|---|---|---|
| React | 18.3.1 | UI framework |
| TypeScript | Latest | Type-safe JavaScript |
| Vite + SWC | Latest | Build tool |
| shadcn/ui (Radix + Tailwind) | Latest | Component library |
| Recharts | Latest | Analytics charts |
| React Router | Latest | Client-side routing |
| TanStack React Query | Latest | Data fetching and caching |

---

## AI / ML Models

| Model | Architecture | File | Size | Purpose |
|---|---|---|---|---|
| Person Detector | YOLOv8n (Nano) | `yolov8n.pt` | 6.2 MB | Person detection for PPE grouping |
| PPE Detector | YOLOv8 (Custom) | `best.pt` | 6.2 MB | Helmet, vest, gloves, boots, mask detection |
| Fire/Smoke Detector | YOLOv8 (Custom) | `fire_best.pt` | 28 MB | Fire and smoke hazard detection |
| Distress Detector | Keras CNN | `cry_model_final_v9.h5` | 28 MB | Audio-based distress detection |

### Inference Pipeline
1. Backend camera worker captures frames from RTSP/webcam feeds
2. Every ~10 frames (~1.5s at 15 FPS), a frame is sent as base64 JPEG to the ML API
3. ML API runs enabled detection models in parallel
4. Detections are returned with bounding boxes, confidence scores, and violation types
5. PPE violations are grouped by person using IoU matching
6. Annotated frame is pushed to MJPEG buffer for live streaming
7. Violations are recorded to Firestore with 24-hour cooldown deduplication

---

## Project Structure

```
fyp/
├── lib/                              # Flutter Mobile App
│   ├── main.dart                     # App entry point
│   ├── firebase_options.dart         # Firebase configuration
│   └── app/
│       ├── core/                     # Config, theme, localization, network
│       ├── data/                     # Models, repositories, services
│       │   ├── models/               # ViolationModel, CameraModel, UserModel
│       │   └── services/             # Auth, Firestore, API, WebSocket, Notifications
│       ├── modules/                  # Feature modules (auth, dashboard, alerts, etc.)
│       ├── routes/                   # GetX route definitions
│       └── binding/                  # Dependency injection
│
├── backend/                          # FastAPI Backend Server
│   ├── app/
│   │   ├── main.py                   # FastAPI app entry with lifespan manager
│   │   ├── api/                      # REST endpoints (cameras, violations, auth, etc.)
│   │   ├── core/                     # Config, Firebase client, JWT security
│   │   ├── models/                   # Enums (UserRole, ViolationType, Severity)
│   │   ├── schemas/                  # Pydantic request/response schemas
│   │   ├── workers/                  # Camera workers, frame store, detectors
│   │   └── ws/                       # WebSocket handler
│   ├── requirements.txt              # Python dependencies
│   ├── requirements-ai.txt           # ML/AI dependencies
│   └── .env.example                  # Environment variable template
│
├── ai_inference/                     # ML Inference Microservice
│   └── ml_api/
│       ├── main.py                   # FastAPI inference server (port 8001)
│       ├── config.py                 # Model paths and thresholds
│       ├── detect_router.py          # Unified /detect endpoint
│       ├── models_logic/             # Helmet, fire, safe zone detection logic
│       ├── weights/                  # Trained model weight files
│       ├── known_faces/              # Face recognition embeddings
│       └── requirements.txt          # ML dependencies
│
├── web_frontend/                     # React Admin Dashboard
│   ├── src/
│   │   ├── main.tsx                  # React entry point
│   │   ├── App.tsx                   # Main routing
│   │   ├── pages/                    # Admin, Site, Auth pages
│   │   ├── components/               # UI components (CameraStream, SafeZoneDrawer)
│   │   ├── context/                  # React context providers
│   │   ├── hooks/                    # Custom React hooks
│   │   └── lib/                      # API clients, utilities
│   ├── package.json                  # Node.js dependencies
│   └── vite.config.ts                # Vite build configuration
│
├── assets/                           # Flutter assets (icons, locales)
├── android/                          # Android platform code
├── ios/                              # iOS platform code
├── pubspec.yaml                      # Flutter dependencies
└── firebase.json                     # Firebase project configuration
```

---

## Prerequisites

Ensure the following are installed on your system before setup:

| Software | Version | Download |
|---|---|---|
| Flutter SDK | 3.x | https://docs.flutter.dev/get-started/install |
| Dart SDK | 3.x | Included with Flutter |
| Python | 3.11+ | https://www.python.org/downloads/ |
| Node.js | 18+ | https://nodejs.org/ |
| Git | Latest | https://git-scm.com/ |
| Android Studio / VS Code | Latest | For Flutter development |
| Firebase CLI | Latest | https://firebase.google.com/docs/cli |

**Hardware Recommendations (for ML Inference):**
- NVIDIA GPU with CUDA support (recommended for real-time inference)
- Minimum 8 GB RAM
- CPU-only mode is supported but slower

---

## Installation & Setup Instructions

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd fyp
```

### Step 2: Flutter Mobile App Setup

```bash
# Install Flutter dependencies
flutter pub get

# Configure Firebase (ensure google-services.json and GoogleService-Info.plist are in place)
# android/app/google-services.json
# ios/Runner/GoogleService-Info.plist

# Run on connected device or emulator
flutter run
```

### Step 3: Backend API Setup

```bash
cd backend

# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Copy and configure environment variables
copy .env.example .env
# Edit .env with your Firebase credentials, JWT secret, etc.

# Run the backend server
uvicorn app.main:app --reload --port 8000
```

### Step 4: ML Inference Service Setup

```bash
cd ai_inference/ml_api

# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate        # Windows

# Install ML dependencies
pip install -r requirements.txt

# Run the inference server
uvicorn main:app --port 8001
```

### Step 5: Web Admin Dashboard Setup

```bash
cd web_frontend

# Install Node.js dependencies
npm install

# Run development server
npm run dev
# Dashboard will be available at http://localhost:5173
```

### Step 6: Firebase Configuration

1. Create a Firebase project at https://console.firebase.google.com
2. Enable Firestore Database and Cloud Storage
3. Download `serviceAccountKey.json` and place it in `backend/`
4. Configure Flutter Firebase using FlutterFire CLI or manual setup

---

## How to Run (All Services)

Open **four separate terminals** and run:

| Terminal | Command | Port |
|---|---|---|
| 1. Backend API | `cd backend && uvicorn app.main:app --reload --port 8000` | 8000 |
| 2. ML Inference | `cd ai_inference/ml_api && uvicorn main:app --port 8001` | 8001 |
| 3. Web Dashboard | `cd web_frontend && npm run dev` | 5173 |
| 4. Mobile App | `flutter run` | Device |

### Environment Variables (Backend)

Create a `.env` file in the `backend/` directory based on `.env.example`:

```env
JWT_SECRET=your_jwt_secret_key
ML_API_URL=http://localhost:8001
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

---

## Database Design

The system uses **Firebase Firestore** (NoSQL) with the following collections:

| Collection | Key Fields | Description |
|---|---|---|
| `officers` | loginId, email, password, status, siteIds | User accounts with site-scoped access |
| `cameras` | id, name, rtsp_url, location, enabled, safe_zone_polygon, enabled_models | Camera configurations |
| `violations` | id, camera_id, type, severity, confidence, status, detected_at, snapshot_url | Detected safety violations |
| `sites` | name, address, enabled | Construction site records |
| `alerts` | violation_id, channel, sent_at | Notification delivery history |

**Firebase Cloud Storage:** `/violations/{violation_id}/snapshot.jpg` -- violation frame captures

---

## API Documentation

The backend exposes the following RESTful endpoints:

| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/login` | User authentication, returns JWT |
| POST | `/auth/refresh` | Refresh access token |
| GET | `/cameras` | List all cameras |
| PUT | `/cameras/{id}/toggle` | Enable/disable a camera |
| GET | `/violations` | Query violations (with filters) |
| PUT | `/violations/{id}/status` | Update violation status |
| GET | `/safe-zone/{camera_id}` | Get safe zone polygon |
| PUT | `/safe-zone/{camera_id}` | Update safe zone polygon |
| GET | `/ai-controls/{camera_id}` | Get enabled AI models |
| PUT | `/ai-controls/{camera_id}` | Toggle AI models |
| GET | `/stream/{camera_id}` | MJPEG live stream |
| WS | `/ws` | Real-time violation WebSocket |
| GET | `/health` | Health check |
| POST | `/detect` *(ML API)* | Unified inference endpoint |

Interactive API docs are available at `http://localhost:8000/docs` (Swagger UI) when the backend is running.

---

## Testing

### Backend API Testing
```bash
cd backend
pytest                          # Run all tests
pytest --cov=app                # Run with coverage report
```

### Flutter App Testing
```bash
flutter test                    # Run unit and widget tests
flutter test --coverage         # Run with coverage
```

### Web Dashboard Testing
```bash
cd web_frontend
npm run test                    # Run tests
npm run lint                    # Lint check
```

### ML Model Evaluation
Model evaluation results are stored in:
- `ai_inference/helmet_eval_results.json` -- PPE detection model metrics
- `ai_inference/fire_eval_results.json` -- Fire/smoke detection model metrics

---

## Screenshots

*(Add screenshots of the following screens for your FYP report and poster:)*

1. Mobile App -- Login Screen
2. Mobile App -- Dashboard with violation summary
3. Mobile App -- Live Camera Feed with AI annotations
4. Mobile App -- Real-time Alerts
5. Mobile App -- Violation History
6. Mobile App -- Analytics Charts
7. Web Dashboard -- Admin Panel
8. Web Dashboard -- Live Stream with Safe Zone
9. Web Dashboard -- Camera Management
10. AI Detection -- PPE violation detection output
11. AI Detection -- Fire/smoke detection output

---

## Known Issues & Limitations

1. ML inference requires GPU for optimal real-time performance; CPU-only mode results in higher latency.
2. RTSP stream connectivity depends on network stability and camera compatibility.
3. Face recognition module is in early stages and requires a pre-populated known faces database.
4. Audio-based distress detection (cry detection) is experimental.
5. The system currently supports webcam and IP cameras via RTSP protocol only.

---

## Future Work

1. **Edge Deployment** -- Deploy ML models on edge devices (e.g., NVIDIA Jetson) for on-site inference without cloud dependency.
2. **Multi-Camera Tracking** -- Track individuals across multiple camera feeds using Re-ID techniques.
3. **Incident Reporting** -- Automated PDF report generation for safety incidents.
4. **Historical Analytics** -- Long-term trend analysis with predictive safety scoring.
5. **Mobile Notifications via FCM** -- Full Firebase Cloud Messaging integration for push notifications.
6. **Audio Alerts** -- Expand distress detection to include environmental audio analysis.
7. **Compliance Dashboard** -- Generate safety compliance reports per regulatory standards (OSHA, ISO 45001).

---

## References

1. Ultralytics YOLOv8 Documentation -- https://docs.ultralytics.com/
2. FastAPI Documentation -- https://fastapi.tiangolo.com/
3. Flutter Documentation -- https://docs.flutter.dev/
4. Firebase Documentation -- https://firebase.google.com/docs
5. React Documentation -- https://react.dev/
6. OpenCV Documentation -- https://docs.opencv.org/
7. PyTorch Documentation -- https://pytorch.org/docs/

---

## Acknowledgments

We would like to express our sincere gratitude to our supervisor for their guidance and support throughout this project. We also thank the Department of Computer Science, COMSATS University Islamabad, Lahore Campus, for providing the resources and platform to complete this Final Year Project.

---

## CD Contents (As Per COMSATS FYP Submission Requirements)

This repository corresponds to the **source code** deliverable. Each submitted CD should contain:

1. **Source Code** -- This complete repository
2. **FYP Report** -- Soft copy of the final report (PDF)
3. **Poster** -- FYP poster (PDF/Image)

> **Note:** CDs must be labeled with the **Group ID** and **Project Title** on the back.

---

*COMSATS University Islamabad, Lahore Campus -- Department of Computer Science -- Final Year Project*
