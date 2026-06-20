/**
 * SiteDataContext
 *
 * A single shared cache for the site-level data that is fetched on almost
 * every sub-page (cameras, sites, violations).  Sub-pages subscribe to this
 * context instead of each making their own Firestore calls.
 *
 * Benefits:
 *  - One load per session instead of one load per navigation.
 *  - Violations/alerts stream is opened once and shared.
 *  - In-memory camera+site list is reused across AlertsPage, HistoryPage,
 *    Dashboard and CamerasPage without any prop-drilling.
 */
import React, {
  createContext, useContext, useEffect, useState, useRef, useCallback
} from 'react';
import { syncSiteOfficerSession, type SiteOfficerSession } from '@/lib/authSession';
import { getAllSites, type Site } from '@/lib/firebaseSites';
import { getCamerasBySite, type Camera } from '@/lib/firebaseCameras';
import { subscribeToViolations, subscribeToAlerts, type ViolationRecord } from '@/lib/firebaseViolations';

interface SiteDataState {
  session: SiteOfficerSession | null;
  sites: Site[];
  cameras: Camera[];
  violations: ViolationRecord[];
  alerts: any[];
  loading: boolean;
  cameraIds: string[];
  myViolations: ViolationRecord[];
  openViolations: ViolationRecord[];
  refresh: () => void;
}

const SiteDataContext = createContext<SiteDataState | null>(null);

export function SiteDataProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<SiteOfficerSession | null>(null);
  const [sites, setSites] = useState<Site[]>([]);
  const [cameras, setCameras] = useState<Camera[]>([]);
  const [violations, setViolations] = useState<ViolationRecord[]>([]);
  const [alerts, setAlerts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const loadedRef = useRef(false);

  const load = useCallback(async (force = false) => {
    if (loadedRef.current && !force) return;
    setLoading(true);
    try {
      const officer = await syncSiteOfficerSession();
      setSession(officer);
      if (!officer?.siteIds?.length) return;

      const [allSites] = await Promise.all([getAllSites()]);
      const mySites = allSites.filter(s => officer.siteIds.includes(s.id || ''));
      setSites(mySites);

      const camArrays = await Promise.all(mySites.map(s => getCamerasBySite(s.id!)));
      setCameras(camArrays.flat());
      loadedRef.current = true;
    } catch (e) {
      console.error('SiteDataProvider load error', e);
    } finally {
      setLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => { load(); }, []);

  // Real-time subscriptions (opened once for the lifetime of the layout)
  useEffect(() => {
    const unsubV = subscribeToViolations(v => setViolations(v), 50);
    const unsubA = subscribeToAlerts(a => setAlerts(a), 20);
    return () => { unsubV(); unsubA(); };
  }, []);

  const cameraIds = cameras.map(c => c.id!);
  const myViolations = violations.filter(v => cameraIds.includes(v.camera_id));
  const openViolations = myViolations.filter(v => v.status === 'open');

  return (
    <SiteDataContext.Provider value={{
      session, sites, cameras, violations, alerts,
      loading, cameraIds, myViolations, openViolations,
      refresh: () => load(true),
    }}>
      {children}
    </SiteDataContext.Provider>
  );
}

export function useSiteData() {
  const ctx = useContext(SiteDataContext);
  if (!ctx) throw new Error('useSiteData must be used inside SiteDataProvider');
  return ctx;
}
