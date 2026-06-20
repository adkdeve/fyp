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

const OFFICERS_COLLECTION = 'officers';

export interface Officer {
  id?: string;
  name: string;
  email: string;
  phone: string;
  loginId?: string;
  password?: string;
  siteIds: string[];
  status: 'active' | 'inactive';
  joinDate: string;
  createdAt?: string;
  updatedAt?: string;
}

// Create a new officer
export const createOfficer = async (officer: Omit<Officer, 'id' | 'createdAt' | 'updatedAt'>) => {
  const officerWithTimestamp = {
    ...officer,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const docRef = await addDoc(collection(db, OFFICERS_COLLECTION), officerWithTimestamp);
  return { ...officer, id: docRef.id, ...officerWithTimestamp };
};

// Get all officers
export const getAllOfficers = async (): Promise<Officer[]> => {
  const q = query(collection(db, OFFICERS_COLLECTION), orderBy('createdAt', 'desc'));
  const querySnapshot = await getDocs(q);
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Officer));
};

// Get officer by login ID or email
export const getOfficerByLogin = async (identifier: string): Promise<Officer | null> => {
  const normalized = identifier.trim().toLowerCase();
  if (!normalized) return null;

  const byEmail = query(
    collection(db, OFFICERS_COLLECTION),
    where('email', '==', normalized)
  );
  const emailSnapshot = await getDocs(byEmail);
  if (!emailSnapshot.empty) {
    const officerDoc = emailSnapshot.docs[0];
    return { id: officerDoc.id, ...officerDoc.data() } as Officer;
  }

  const byLoginId = query(
    collection(db, OFFICERS_COLLECTION),
    where('loginId', '==', normalized)
  );
  const loginIdSnapshot = await getDocs(byLoginId);
  if (!loginIdSnapshot.empty) {
    const officerDoc = loginIdSnapshot.docs[0];
    return { id: officerDoc.id, ...officerDoc.data() } as Officer;
  }

  return null;
};

// Get officers by site
export const getOfficersBySite = async (siteId: string): Promise<Officer[]> => {
  const q = query(
    collection(db, OFFICERS_COLLECTION),
    where('siteIds', 'array-contains', siteId),
    orderBy('createdAt', 'desc')
  );
  const querySnapshot = await getDocs(q);
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Officer));
};

// Get a single officer by ID
export const getOfficerById = async (id: string): Promise<Officer | null> => {
  const docRef = doc(db, OFFICERS_COLLECTION, id);
  const docSnap = await getDoc(docRef);
  if (docSnap.exists()) {
    return { id: docSnap.id, ...docSnap.data() } as Officer;
  }
  return null;
};

// Update an officer
export const updateOfficer = async (id: string, updates: Partial<Officer>) => {
  const docRef = doc(db, OFFICERS_COLLECTION, id);
  const updatedData = {
    ...updates,
    updatedAt: new Date().toISOString(),
  };
  await updateDoc(docRef, updatedData);
  return { id, ...updatedData };
};

// Delete an officer
export const deleteOfficer = async (id: string) => {
  const docRef = doc(db, OFFICERS_COLLECTION, id);
  await deleteDoc(docRef);
};

// Subscribe to officers in real-time
export const subscribeToOfficers = (callback: (officers: Officer[]) => void) => {
  const q = query(collection(db, OFFICERS_COLLECTION), orderBy('createdAt', 'desc'));
  const unsubscribe = onSnapshot(q, (querySnapshot) => {
    const officers = querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Officer));
    callback(officers);
  });
  return unsubscribe;
};

// Assign officer to site
export const assignOfficerToSite = async (officerId: string, siteId: string) => {
  const officerDoc = await getOfficerById(officerId);
  if (!officerDoc) throw new Error('Officer not found');

  const siteIds = officerDoc.siteIds || [];
  if (!siteIds.includes(siteId)) {
    await updateOfficer(officerId, { siteIds: [...siteIds, siteId] });
  }
};

// Unassign officer from site
export const unassignOfficerFromSite = async (officerId: string, siteId: string) => {
  const officerDoc = await getOfficerById(officerId);
  if (!officerDoc) throw new Error('Officer not found');

  const siteIds = officerDoc.siteIds || [];
  await updateOfficer(officerId, { siteIds: siteIds.filter(id => id !== siteId) });
};
