"""
Legacy db module — replaced by Firebase.
Kept for import compatibility. All data now goes through Firestore.
"""
from .firebase_db import get_firestore, init_firebase

__all__ = ["get_firestore", "init_firebase"]
