"""
/api/v1/faces — Backend proxy for the ML service's authorized persons management.

Proxies all requests to ML_API_URL/faces/* so the frontend only needs to
talk to the backend (port 8000), avoiding CORS port-switching issues.
"""
import logging
import httpx
from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse

from ..core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/faces", tags=["Authorized Persons"])

ML_FACES_URL = lambda path="": f"{settings.ml_api_url.rstrip('/')}/faces{path}"


async def _proxy_get(path: str):
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.get(ML_FACES_URL(path))
            r.raise_for_status()
            return r.json()
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="ML service unreachable")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


async def _proxy_delete(path: str):
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.delete(ML_FACES_URL(path))
            r.raise_for_status()
            return r.json()
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="ML service unreachable")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── List all persons ──────────────────────────────────────────────────────────
@router.get("/persons")
async def list_persons():
    return await _proxy_get("/persons")


# ── Add person + images ───────────────────────────────────────────────────────
@router.post("/persons/{name}")
async def add_person_images(name: str, files: list[UploadFile] = File(...)):
    """Upload face images for an authorized person (forwards to ML service)."""
    try:
        form_files = []
        for upload in files:
            content = await upload.read()
            form_files.append(
                ("files", (upload.filename or "photo.jpg", content, upload.content_type or "image/jpeg"))
            )
        async with httpx.AsyncClient(timeout=60.0) as client:
            r = await client.post(
                ML_FACES_URL(f"/persons/{name}"),
                files=form_files,
            )
            r.raise_for_status()
            return r.json()
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="ML service unreachable")
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Delete person ─────────────────────────────────────────────────────────────
@router.delete("/persons/{name}")
async def delete_person(name: str):
    return await _proxy_delete(f"/persons/{name}")


# ── Delete specific image ─────────────────────────────────────────────────────
@router.delete("/persons/{name}/images/{filename}")
async def delete_person_image(name: str, filename: str):
    return await _proxy_delete(f"/persons/{name}/images/{filename}")


# ── Rebuild embeddings ────────────────────────────────────────────────────────
@router.post("/rebuild")
async def rebuild_embeddings():
    """Trigger embedding rebuild on the ML service after adding/removing persons."""
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:  # rebuilding can take time
            r = await client.post(ML_FACES_URL("/rebuild"))
            r.raise_for_status()
            return r.json()
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="ML service unreachable")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Get person thumbnail ──────────────────────────────────────────────────────
@router.get("/persons/{name}/thumb")
async def get_person_thumb(name: str):
    return await _proxy_get(f"/persons/{name}/thumb")
