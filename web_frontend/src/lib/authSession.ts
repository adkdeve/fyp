import { getOfficerById } from './firebaseOfficers';
import { getSitesByOfficerId } from './firebaseSites';

export interface SiteOfficerSession {
  id: string;
  name: string;
  email: string;
  phone: string;
  loginId?: string;
  siteIds: string[];
  status: 'active' | 'inactive';
}

const SITE_OFFICER_KEY = 'site_officer';
const LEGACY_SITE_KEY = 'site';

export const getSiteOfficerSession = (): SiteOfficerSession | null => {
  const raw = localStorage.getItem(SITE_OFFICER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as SiteOfficerSession;
  } catch {
    return null;
  }
};

export const setSiteOfficerSession = (session: SiteOfficerSession) => {
  localStorage.setItem(SITE_OFFICER_KEY, JSON.stringify(session));
  // Keep old key so existing checks stay compatible.
  localStorage.setItem(LEGACY_SITE_KEY, 'authenticated');
};

export const clearSiteOfficerSession = () => {
  localStorage.removeItem(SITE_OFFICER_KEY);
  localStorage.removeItem(LEGACY_SITE_KEY);
};

export const syncSiteOfficerSession = async (): Promise<SiteOfficerSession | null> => {
  const session = getSiteOfficerSession();
  if (!session?.id) return null;

  const latest = await getOfficerById(session.id);
  if (!latest || latest.status !== 'active') {
    clearSiteOfficerSession();
    return null;
  }

  const updatedSession: SiteOfficerSession = {
    id: latest.id || session.id,
    name: latest.name || session.name,
    email: latest.email || session.email,
    phone: latest.phone || session.phone,
    loginId: latest.loginId || session.loginId,
    siteIds: latest.siteIds || [],
    status: latest.status,
  };

  // Backward compatibility: merge both mapping styles.
  const mappedSites = await getSitesByOfficerId(updatedSession.id);
  if (mappedSites.length) {
    const mappedIds = mappedSites
      .map((site) => site.id || '')
      .filter(Boolean);
    updatedSession.siteIds = Array.from(
      new Set([...(updatedSession.siteIds || []), ...mappedIds])
    );
  }

  setSiteOfficerSession(updatedSession);
  return updatedSession;
};
