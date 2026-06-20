/**
 * ML Service API client — updated to call backend /api/v1/ai-controls
 * instead of the ML service directly.
 *
 * This solves the critical bug where:
 *   - ML service resets all flags to false on restart
 *   - Frontend only re-synced on Settings page visit
 *   - Face recognition / PPE / fire detection stopped working after any ML restart
 *
 * New flow:
 *   Frontend → Backend /api/v1/ai-controls/toggle
 *   Backend stores in-memory + broadcasts to all running camera workers
 *   Camera workers pass enabled_models with EVERY /detect call → ML service always works
 */

const BACKEND_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';
const ML_URL = import.meta.env.VITE_ML_URL || 'http://localhost:8001';

const STORAGE_KEY = 'ml_detection_prefs';

export interface DetectionPrefs {
  ppe: boolean;       // Helmet/vest/mask detection
  fire: boolean;      // Fire & smoke detection
  face: boolean;      // Face recognition
}

function loadPrefs(): DetectionPrefs {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch { }
  return { ppe: false, fire: false, face: false };
}

function savePrefs(prefs: DetectionPrefs) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
}

/** Map frontend prefs keys → backend model keys */
function prefsToModels(prefs: DetectionPrefs): Record<string, boolean> {
  return {
    helmet: prefs.ppe,
    firesmoke: prefs.fire,
    face_insight: prefs.face,
  };
}

async function callBackend(path: string, body: object): Promise<boolean> {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/ai-controls${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(5000),
    });
    return res.ok;
  } catch {
    return false;
  }
}

export const mlApi = {
  /** Base URL of the ML service (for streaming etc.) */
  baseUrl: ML_URL,

  /** Get the current AI controls status from the BACKEND (not ML service) */
  async getStatus(): Promise<{ active_models: Record<string, boolean>; service: string } | null> {
    try {
      // Try backend AI controls status first (preferred — stable)
      const res = await fetch(`${BACKEND_URL}/api/v1/ai-controls/status`, {
        signal: AbortSignal.timeout(3000),
      });
      if (res.ok) {
        const data = await res.json();
        // Normalize to the format expected by AIDetectionControls
        // backend uses {helmet, firesmoke, face_insight}
        const am = data.active_models || {};
        return {
          service: 'backend',
          active_models: {
            helmet: am.helmet ?? false,
            firesmoke: am.firesmoke ?? false,
            face_insight: am.face_insight ?? false,
            // also expose safezone for AIDetectionControls
            safezone: am.safezone ?? false,
          },
        };
      }
    } catch { }

    // Fall back to ML service status
    try {
      const res = await fetch(`${ML_URL}/status`, { signal: AbortSignal.timeout(3000) });
      if (res.ok) return res.json();
    } catch { }
    return null;
  },

  /** Toggle PPE (helmet) detection */
  async togglePPE(active: boolean): Promise<boolean> {
    return callBackend('/toggle', { model: 'helmet', active });
  },

  /** Toggle Fire & Smoke detection */
  async toggleFire(active: boolean): Promise<boolean> {
    return callBackend('/toggle', { model: 'firesmoke', active });
  },

  /** Toggle Face recognition (InsightFace) */
  async toggleFace(active: boolean): Promise<boolean> {
    return callBackend('/toggle', { model: 'face_insight', active });
  },

  /** Toggle Safe Zone monitoring (still calls ML service for legacy support) */
  async toggleSafeZone(active: boolean): Promise<boolean> {
    try {
      const res = await fetch(`${ML_URL}/models/safe-zone/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active }),
        signal: AbortSignal.timeout(5000),
      });
      return res.ok;
    } catch {
      return false;
    }
  },

  /** Load saved local preferences */
  loadPrefs,

  /** Save preferences locally */
  savePrefs,

  /**
   * Apply saved preferences to the backend (and via backend to camera workers).
   * Call this on app startup to re-sync after page refresh.
   */
  async applyPrefs(prefs: DetectionPrefs): Promise<void> {
    await callBackend('/bulk', { models: prefsToModels(prefs) });
  },
};

export default mlApi;
