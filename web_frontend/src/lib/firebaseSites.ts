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

const SITES_COLLECTION = 'sites';

export interface Site {
  id?: string;
  name: string;
  location: string;
  status: 'active' | 'inactive';
  cameraIds: string[];
  officerIds: string[];
  createdAt?: string;
  updatedAt?: string;
}

// Create a new site
export const createSite = async (site: Omit<Site, 'id' | 'createdAt' | 'updatedAt'>) => {
  const siteWithTimestamp = {
    ...site,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const docRef = await addDoc(collection(db, SITES_COLLECTION), siteWithTimestamp);
  return { ...site, id: docRef.id, ...siteWithTimestamp };
};

// Get all sites
export const getAllSites = async (): Promise<Site[]> => {
  const q = query(collection(db, SITES_COLLECTION), orderBy('createdAt', 'desc'));
  const querySnapshot = await getDocs(q);
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Site));
};

// Get sites assigned to a specific officer (legacy/alternate mapping support)
export const getSitesByOfficerId = async (officerId: string): Promise<Site[]> => {
  const q = query(
    collection(db, SITES_COLLECTION),
    where('officerIds', 'array-contains', officerId)
  );
  const querySnapshot = await getDocs(q);
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Site));
};

// Get a single site by ID
export const getSiteById = async (id: string): Promise<Site | null> => {
  const docRef = doc(db, SITES_COLLECTION, id);
  const docSnap = await getDoc(docRef);
  if (docSnap.exists()) {
    return { id: docSnap.id, ...docSnap.data() } as Site;
  }
  return null;
};

// Update a site
export const updateSite = async (id: string, updates: Partial<Site>) => {
  const docRef = doc(db, SITES_COLLECTION, id);
  const updatedData = {
    ...updates,
    updatedAt: new Date().toISOString(),
  };
  await updateDoc(docRef, updatedData);
  return { id, ...updatedData };
};

// Delete a site
export const deleteSite = async (id: string) => {
  const docRef = doc(db, SITES_COLLECTION, id);
  await deleteDoc(docRef);
};

// Subscribe to sites in real-time
export const subscribeToSites = (callback: (sites: Site[]) => void) => {
  const q = query(collection(db, SITES_COLLECTION), orderBy('createdAt', 'desc'));
  const unsubscribe = onSnapshot(q, (querySnapshot) => {
    const sites = querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Site));
    callback(sites);
  });
  return unsubscribe;
};

// Assign camera to site
export const assignCameraToSite = async (cameraId: string, siteId: string) => {
  const siteDoc = await getSiteById(siteId);
  if (!siteDoc) throw new Error('Site not found');

  const cameraIds = siteDoc.cameraIds || [];
  if (!cameraIds.includes(cameraId)) {
    await updateSite(siteId, { cameraIds: [...cameraIds, cameraId] });
  }
};

// Unassign camera from site
export const unassignCameraFromSite = async (cameraId: string, siteId: string) => {
  const siteDoc = await getSiteById(siteId);
  if (!siteDoc) throw new Error('Site not found');

  const cameraIds = siteDoc.cameraIds || [];
  await updateSite(siteId, { cameraIds: cameraIds.filter(id => id !== cameraId) });
};

// Assign officer to site
export const assignOfficerToSite = async (officerId: string, siteId: string) => {
  const siteDoc = await getSiteById(siteId);
  if (!siteDoc) throw new Error('Site not found');

  const officerIds = siteDoc.officerIds || [];
  if (!officerIds.includes(officerId)) {
    await updateSite(siteId, { officerIds: [...officerIds, officerId] });
  }
};

// Unassign officer from site
export const unassignOfficerFromSite = async (officerId: string, siteId: string) => {
  const siteDoc = await getSiteById(siteId);
  if (!siteDoc) throw new Error('Site not found');

  const officerIds = siteDoc.officerIds || [];
  await updateSite(siteId, { officerIds: officerIds.filter(id => id !== officerId) });
};
