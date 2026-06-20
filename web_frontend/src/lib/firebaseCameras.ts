import { db } from './firebase';
import {
  collection,
  addDoc,
  getDocs,
  getDoc,
  updateDoc,
  deleteDoc,
  doc,
  query,
  where,
  orderBy,
  onSnapshot,
} from 'firebase/firestore';

const CAMERAS_COLLECTION = 'cameras';

export interface Camera {
  id?: string;
  name: string;
  location: string;
  rtsp_url: string;
  site_id: string | null;
  enabled: boolean;
  status: string;
  fps_target: number;
  createdAt?: string;
  updatedAt?: string;
}

// Create a new camera
export const createCamera = async (camera: Omit<Camera, 'id' | 'createdAt' | 'updatedAt'>) => {
  const cameraWithTimestamp = {
    ...camera,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const docRef = await addDoc(collection(db, CAMERAS_COLLECTION), cameraWithTimestamp);
  return { ...camera, id: docRef.id, ...cameraWithTimestamp };
};

// Get all cameras
export const getAllCameras = async (): Promise<Camera[]> => {
  const q = query(collection(db, CAMERAS_COLLECTION), orderBy('createdAt', 'desc'));
  const querySnapshot = await getDocs(q);
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Camera));
};

// Get cameras by site
export const getCamerasBySite = async (siteId: string): Promise<Camera[]> => {
  const q = query(
    collection(db, CAMERAS_COLLECTION),
    where('site_id', '==', siteId)
  );
  const querySnapshot = await getDocs(q);
  const results = querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Camera));
  return results.sort((a, b) => {
    const timeA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
    const timeB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
    return timeB - timeA;
  });
};

// Get a single camera by ID
export const getCameraById = async (id: string): Promise<Camera | null> => {
  const docRef = doc(db, CAMERAS_COLLECTION, id);
  const docSnap = await getDoc(docRef);
  if (docSnap.exists()) {
    return { id: docSnap.id, ...docSnap.data() } as Camera;
  }
  return null;
};

// Update a camera
export const updateCamera = async (id: string, updates: Partial<Camera>) => {
  const docRef = doc(db, CAMERAS_COLLECTION, id);
  const updatedData = {
    ...updates,
    updatedAt: new Date().toISOString(),
  };
  await updateDoc(docRef, updatedData);
  return { id, ...updatedData };
};

// Delete a camera
export const deleteCamera = async (id: string) => {
  const docRef = doc(db, CAMERAS_COLLECTION, id);
  await deleteDoc(docRef);
};

// Subscribe to cameras in real-time
export const subscribeToCameras = (callback: (cameras: Camera[]) => void) => {
  const q = query(collection(db, CAMERAS_COLLECTION), orderBy('createdAt', 'desc'));
  const unsubscribe = onSnapshot(q, (querySnapshot) => {
    const cameras = querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Camera));
    callback(cameras);
  });
  return unsubscribe;
};

// Assign camera to site
export const assignCameraToSite = async (cameraId: string, siteId: string) => {
  const cameraDoc = await getCameraById(cameraId);
  if (!cameraDoc) throw new Error('Camera not found');

  await updateCamera(cameraId, { site_id: siteId });
};

// Unassign camera from site
export const unassignCameraFromSite = async (cameraId: string) => {
  const cameraDoc = await getCameraById(cameraId);
  if (!cameraDoc) throw new Error('Camera not found');

  await updateCamera(cameraId, { site_id: null });
};
