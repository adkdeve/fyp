/**
 * API client for communicating with the FastAPI backend.
 * Backend handles: video streaming, YOLO detection, violation recording.
 * All CRUD data (cameras, sites, officers) is managed via Firebase directly.
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

export const api = {
  /** Get the MJPEG stream URL for a camera (use in <img> src) */
  getStreamUrl(cameraId: string): string {
    return `${API_URL}/api/v1/stream/${cameraId}`;
  },

  /** Get a single JPEG frame URL */
  getFrameUrl(cameraId: string): string {
    return `${API_URL}/api/v1/stream/${cameraId}/frame`;
  },

  /** Start a camera worker on the backend */
  async startCamera(cameraId: string, rtspUrl: string) {
    const res = await fetch(`${API_URL}/api/v1/cameras/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ camera_id: cameraId, rtsp_url: rtspUrl }),
    });
    return res.json();
  },

  /** Stop a camera worker */
  async stopCamera(cameraId: string) {
    const res = await fetch(`${API_URL}/api/v1/cameras/stop/${cameraId}`, {
      method: 'POST',
    });
    return res.json();
  },

  /** Get list of active camera workers */
  async getActiveCameras(): Promise<{ active: string[] }> {
    const res = await fetch(`${API_URL}/api/v1/cameras/active`);
    return res.json();
  },

  /** Get violations list */
  async getViolations(cameraId?: string, limit = 50) {
    const params = new URLSearchParams();
    if (cameraId) params.set('camera_id', cameraId);
    params.set('limit', String(limit));
    const res = await fetch(`${API_URL}/api/v1/violations?${params}`);
    return res.json();
  },

  /** Check backend health */
  async healthCheck() {
    try {
      const res = await fetch(`${API_URL}/health`);
      return res.json();
    } catch {
      return { status: 'offline' };
    }
  },

  /** Get WebSocket URL for real-time violations */
  getWebSocketUrl(): string {
    const wsBase = API_URL.replace('http://', 'ws://').replace('https://', 'wss://');
    return `${wsBase}/ws`;
  },

  /** Set safe zone polygon for a camera */
  async setSafeZone(cameraId: string, points: { x: number; y: number }[]) {
    const res = await fetch(`${API_URL}/api/v1/safe-zone/set`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ camera_id: cameraId, points }),
    });
    return res.json();
  },

  /** Clear safe zone polygon for a camera */
  async clearSafeZone(cameraId: string) {
    const res = await fetch(`${API_URL}/api/v1/safe-zone/clear/${cameraId}`, {
      method: 'DELETE',
    });
    return res.json();
  },

  /** Get current safe zone polygon for a camera */
  async getSafeZone(cameraId: string): Promise<{ camera_id: string; points: [number, number][] }> {
    const res = await fetch(`${API_URL}/api/v1/safe-zone/${cameraId}`);
    return res.json();
  },
};

export default api;
