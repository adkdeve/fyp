import { db } from './firebase';
import {
  collection,
  getDocs,
  query,
  orderBy,
  where,
  onSnapshot,
  limit as firestoreLimit,
} from 'firebase/firestore';

export interface ViolationRecord {
  id: string;
  camera_id: string;
  camera_name?: string;
  type: string;
  severity: string;
  status: string;
  confidence: number;
  snapshot_url?: string;
  detected_at: string;
  resolved_at?: string;
  notes?: string;
}

import { doc, getDoc, updateDoc } from 'firebase/firestore';

export const getViolationById = async (id: string): Promise<ViolationRecord | null> => {
  const docRef = doc(db, 'violations', id);
  const docSnap = await getDoc(docRef);
  if (docSnap.exists()) {
    return { id: docSnap.id, ...docSnap.data() } as ViolationRecord;
  }
  return null;
};

export const updateViolationStatus = async (id: string, status: string): Promise<void> => {
  const docRef = doc(db, 'violations', id);
  await updateDoc(docRef, { status, resolved_at: status !== 'open' ? new Date().toISOString() + 'Z' : null });
};

/** Get all violations from Firestore */
export const getAllViolations = async (limitCount = 50): Promise<ViolationRecord[]> => {
  const q = query(
    collection(db, 'violations'),
    orderBy('detected_at', 'desc'),
    firestoreLimit(limitCount)
  );
  const snap = await getDocs(q);
  return snap.docs.map(doc => ({ id: doc.id, ...doc.data() } as ViolationRecord));
};

/** Get violations by camera */
export const getViolationsByCamera = async (cameraId: string): Promise<ViolationRecord[]> => {
  const q = query(
    collection(db, 'violations'),
    where('camera_id', '==', cameraId)
  );
  const snap = await getDocs(q);
  const results = snap.docs.map(doc => ({ id: doc.id, ...doc.data() } as ViolationRecord));
  return results
    .sort((a, b) => new Date(b.detected_at).getTime() - new Date(a.detected_at).getTime())
    .slice(0, 50);
};

/** Subscribe to violations in real-time */
export const subscribeToViolations = (
  callback: (violations: ViolationRecord[]) => void,
  limitCount = 20
) => {
  const q = query(
    collection(db, 'violations'),
    orderBy('detected_at', 'desc'),
    firestoreLimit(limitCount)
  );
  return onSnapshot(q, (snap) => {
    const violations = snap.docs.map(doc => ({ id: doc.id, ...doc.data() } as ViolationRecord));
    callback(violations);
  });
};

/** Subscribe to unread alerts in real-time */
export const subscribeToAlerts = (
  callback: (alerts: any[]) => void,
  limitCount = 20
) => {
  const q = query(
    collection(db, 'alerts'),
    orderBy('created_at', 'desc'),
    firestoreLimit(limitCount)
  );
  return onSnapshot(q, (snap) => {
    const alerts = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    callback(alerts);
  });
};
