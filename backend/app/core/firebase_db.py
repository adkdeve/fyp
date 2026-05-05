"""
Firebase Admin SDK initialization.
Uses service account key if available, otherwise falls back to project ID only.
"""
import os
import logging
import firebase_admin
from firebase_admin import credentials, firestore

from .config import settings

logger = logging.getLogger(__name__)

_db = None


def init_firebase():
    """Initialize Firebase Admin SDK and return Firestore client."""
    global _db
    if _db is not None:
        return _db

    key_path = os.path.join(os.path.dirname(__file__), "..", "..", "serviceAccountKey.json")

    if os.path.exists(key_path):
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        logger.info("Firebase initialized with service account key")
    else:
        firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})
        logger.info(f"Firebase initialized with project ID: {settings.firebase_project_id}")

    _db = firestore.client()
    return _db


def get_firestore():
    """Get the Firestore client (lazy init)."""
    global _db
    if _db is None:
        return init_firebase()
    return _db
