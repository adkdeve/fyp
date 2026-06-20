import firebase_admin
from firebase_admin import credentials, firestore
import os

def check_cameras():
    # Use the same logic as the backend to find the firebase credentials
    # Typically it's in a path defined by GOOGLE_APPLICATION_CREDENTIALS
    # or it uses default credentials.
    # Looking at the codebase, it seems to use get_firestore() from core.firebase_db
    
    # Let's try to just list the cameras to see their IDs
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate("/Users/ahmed/Desktop/fyp_next/backend/serviceAccountKey.json")
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        cameras = db.collection("cameras").stream()
        print("Cameras found:")
        for cam in cameras:
            data = cam.to_dict()
            print(f"ID: {cam.id}, Name: {data.get('name')}, SafeZone: {len(data.get('safe_zone_polygon', []))} pts")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_cameras()
