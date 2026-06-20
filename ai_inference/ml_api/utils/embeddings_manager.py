"""
Embeddings Manager - Handles face embedding persistence and management
"""
import os
import pickle
import json
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import numpy as np

from utils.config import (
    EMBEDDINGS_FILE,
    EMBEDDINGS_METADATA_FILE,
    KNOWN_FACES_DIR
)


class EmbeddingsManager:
    """Manages face embeddings storage and retrieval"""
    
    def __init__(self, embeddings_file: Optional[str] = None, metadata_file: Optional[str] = None):
        self.embeddings_file = embeddings_file or EMBEDDINGS_FILE
        self.metadata_file = metadata_file or EMBEDDINGS_METADATA_FILE
    
    def save_embeddings(
        self, 
        names: List[str], 
        embeddings: np.ndarray,
        metadata: Optional[Dict] = None
    ) -> bool:
        """
        Save face embeddings and metadata to disk
        
        Args:
            names: List of person names
            embeddings: Numpy array of embeddings
            metadata: Optional dictionary with additional info
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Ensure directory exists
            os.makedirs(os.path.dirname(self.embeddings_file), exist_ok=True)
            
            # Save embeddings
            embeddings_data = {
                'names': names,
                'embeddings': embeddings
            }
            
            with open(self.embeddings_file, 'wb') as f:
                pickle.dump(embeddings_data, f)
            
            # Save metadata
            if metadata is None:
                metadata = {}
            
            metadata.update({
                'created_at': datetime.now().isoformat(),
                'num_identities': len(names),
                'names': names
            })
            
            with open(self.metadata_file, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            print(f" Saved {len(names)} face embeddings to {self.embeddings_file}")
            return True
            
        except Exception as e:
            print(f" Error saving embeddings: {str(e)}")
            return False
    
    def load_embeddings(self) -> Tuple[Optional[List[str]], Optional[np.ndarray]]:
        """
        Load face embeddings from disk
        
        Returns:
            Tuple of (names, embeddings) or (None, None) if not found
        """
        try:
            if not os.path.exists(self.embeddings_file):
                print(" No existing embeddings file found")
                return None, None
            
            with open(self.embeddings_file, 'rb') as f:
                data = pickle.load(f)
            
            names = data.get('names', [])
            embeddings = data.get('embeddings', np.array([]))
            
            print(f" Loaded {len(names)} face embeddings from {self.embeddings_file}")
            return names, embeddings
            
        except Exception as e:
            print(f" Error loading embeddings: {str(e)}")
            return None, None
    
    def load_metadata(self) -> Optional[Dict]:
        """Load embeddings metadata"""
        try:
            if not os.path.exists(self.metadata_file):
                return None
            
            with open(self.metadata_file, 'r') as f:
                return json.load(f)
                
        except Exception as e:
            print(f" Error loading metadata: {str(e)}")
            return None
    
    def embeddings_exist(self) -> bool:
        """Check if embeddings file exists"""
        return os.path.exists(self.embeddings_file)
    
    def get_known_faces_folders(self) -> List[str]:
        """Get list of folders in known_faces directory"""
        try:
            if not os.path.exists(KNOWN_FACES_DIR):
                return []
            
            folders = [
                f for f in os.listdir(KNOWN_FACES_DIR)
                if os.path.isdir(os.path.join(KNOWN_FACES_DIR, f))
            ]
            return folders
            
        except Exception as e:
            print(f" Error reading known_faces directory: {str(e)}")
            return []
    
    def get_num_known_faces(self) -> int:
        """Get number of known identities"""
        metadata = self.load_metadata()
        if metadata:
            return metadata.get('num_identities', 0)
        return 0
    
    def clear_embeddings(self) -> bool:
        """Delete embeddings and metadata files"""
        try:
            if os.path.exists(self.embeddings_file):
                os.remove(self.embeddings_file)
            if os.path.exists(self.metadata_file):
                os.remove(self.metadata_file)
            print(" Cleared embeddings")
            return True
        except Exception as e:
            print(f" Error clearing embeddings: {str(e)}")
            return False
