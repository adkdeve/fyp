import React, { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useNavigate, useParams } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { ArrowLeft, AlertTriangle, Loader2, PenLine, Trash2, ShieldOff } from 'lucide-react';
import { getCameraById, type Camera } from '@/lib/firebaseCameras';
import { subscribeToViolations, type ViolationRecord } from '@/lib/firebaseViolations';
import api from '@/lib/api';
import { syncSiteOfficerSession } from '@/lib/authSession';
import { useToast } from '@/hooks/use-toast';
import SafeZoneDrawer, { type NPoint } from '@/components/SafeZoneDrawer';
import CameraStream from '@/components/CameraStream';

const LiveView = () => {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const { toast } = useToast();

  const [camera, setCamera] = useState<Camera | null>(null);
  const [loading, setLoading] = useState(true);
  const [violations, setViolations] = useState<ViolationRecord[]>([]);
  const [streamError, setStreamError] = useState(false);
  const [clearing, setClearing] = useState(false);

  // Safe zone state
  const [savedZone, setSavedZone] = useState<NPoint[]>([]);  // confirmed polygon
  const [showDrawer, setShowDrawer] = useState(false);         // open canvas modal

  // ── Load camera + saved polygon ──────────────────────────────────────────
  useEffect(() => {
    if (!id) return;
    (async () => {
      try {
        const cam = await getCameraById(id);
        const session = await syncSiteOfficerSession();
        if (!cam || !session?.siteIds?.includes(cam.site_id || '')) {
          setCamera(null); return;
        }
        setCamera(cam);

        // Load saved polygon (normalized [[nx, ny], …])
        try {
          const sz = await api.getSafeZone(id);
          if (sz.points && sz.points.length >= 3) {
            setSavedZone(sz.points.map((p: any) => ({
              nx: p.x !== undefined ? p.x : p[0],
              ny: p.y !== undefined ? p.y : p[1]
            })));
          }
        } catch { /* no polygon yet */ }
      } catch (e) {
        console.error('Failed to load camera:', e);
      } finally {
        setLoading(false);
      }
    })();
  }, [id]);

  // ── Violation subscription ────────────────────────────────────────────────
  useEffect(() => {
    if (!id) return;
    const unsub = subscribeToViolations(
      (all) => setViolations(all.filter(v => v.camera_id === id)), 20,
    );
    return () => unsub();
  }, [id]);

  // ── Save polygon from drawer ──────────────────────────────────────────────
  const handleSaveZone = async (points: NPoint[]) => {
    if (!id) return;
    console.log('[LiveView] Saving safe zone:', { id, points });
    try {
      await api.setSafeZone(id, points.map(p => ({ x: p.nx, y: p.ny })));
      setSavedZone(points);
      setShowDrawer(false);
      toast({
        title: '✅ Safe Zone Saved',
        description: `${points.length}-point zone saved. It will appear as a blue box on the live feed within seconds.`,
      });
    } catch (e) {
      toast({ title: 'Save failed', description: String(e), variant: 'destructive' });
      throw e; // re-throw so drawer stays open
    }
  };

  const handleClearZone = async () => {
    if (!id) return;
    setClearing(true);
    try {
      await api.clearSafeZone(id);
      setSavedZone([]);
      toast({ title: '🗑️ Safe Zone Removed', description: 'Zone cleared. The live feed will no longer show the restricted area.' });
    } catch (e) {
      toast({ title: 'Clear failed', description: String(e), variant: 'destructive' });
    } finally {
      setClearing(false);
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────
  if (loading) return (
    <div className="flex justify-center items-center h-64">
      <Loader2 className="h-8 w-8 animate-spin text-primary" />
    </div>
  );

  if (!camera) return (
    <div className="text-center py-12">
      <p className="text-gray-600 dark:text-gray-400">Camera not found.</p>
      <Button onClick={() => navigate(-1)} variant="link" className="mt-4">Go Back</Button>
    </div>
  );

  const streamUrl = api.getStreamUrl(camera.id!);
  const hasSavedZone = savedZone.length >= 3;

  return (
    <>
      {/* ── Canvas Drawing Modal ─────────────────────────────────────────── */}
      {showDrawer && (
        <SafeZoneDrawer
          cameraId={camera.id!}
          streamUrl={streamUrl}
          cameraName={camera.name}
          initialPoints={hasSavedZone ? savedZone : []}
          onSave={handleSaveZone}
          onClose={() => setShowDrawer(false)}
        />
      )}

      <div className="space-y-4">
        {/* ── Header ─────────────────────────────────────────────────────── */}
        <div className="flex items-center gap-3 flex-wrap">
          <Button onClick={() => navigate(-1)} variant="ghost" size="sm">
            <ArrowLeft className="h-4 w-4 mr-1" /> Back
          </Button>
          <h1 className="text-xl font-bold text-gray-900 dark:text-white">{camera.name}</h1>
          <span className={`text-xs px-2 py-1 rounded-full ${camera.enabled
            ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400'
            : 'bg-red-100 text-red-800'
            }`}>
            {camera.enabled ? 'Enabled' : 'Disabled'}
          </span>
          {hasSavedZone && (
            <span className="text-xs px-2 py-1 rounded-full bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300 flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse inline-block" />
              Safe Zone Active
            </span>
          )}
        </div>

        {/* ── Live Feed Card ──────────────────────────────────────────────── */}
        <Card className="dark:bg-gray-800 dark:border-gray-700">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between flex-wrap gap-3">
              <CardTitle className="text-gray-900 dark:text-white flex items-center gap-2">
                <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse" />
                Live Feed — {camera.location || 'Unknown Location'}
              </CardTitle>

              {/* Zone controls — always show both buttons */}
              <div className="flex items-center gap-2 flex-wrap">
                {/* Status badge */}
                {hasSavedZone && (
                  <span className="hidden sm:inline-flex items-center gap-1.5 text-xs font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 px-2.5 py-1 rounded-full">
                    <span className="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse inline-block" />
                    {savedZone.length}-pt zone active
                  </span>
                )}

                {/* Draw / Edit */}
                <Button
                  id="btn-draw-zone"
                  size="sm" variant="outline"
                  onClick={() => setShowDrawer(true)}
                  className="gap-1.5 border-blue-400 text-blue-600 hover:bg-blue-50 dark:text-blue-400 dark:border-blue-700 dark:hover:bg-blue-900/20"
                >
                  <PenLine className="h-3.5 w-3.5" />
                  {hasSavedZone ? 'Edit Zone' : 'Draw Safe Zone'}
                </Button>

                {/* Remove — always visible when zone exists */}
                <Button
                  id="btn-remove-zone"
                  size="sm"
                  variant={hasSavedZone ? 'destructive' : 'ghost'}
                  onClick={handleClearZone}
                  disabled={!hasSavedZone || clearing}
                  className={`gap-1.5 ${hasSavedZone
                    ? 'bg-red-600 hover:bg-red-700 text-white'
                    : 'text-gray-400 opacity-50 cursor-not-allowed'
                    }`}
                >
                  {clearing
                    ? <Loader2 className="h-3.5 w-3.5 animate-spin" />
                    : <ShieldOff className="h-3.5 w-3.5" />}
                  Remove Zone
                </Button>
              </div>
            </div>
          </CardHeader>

          <CardContent>
            {/* Stream */}
            <div className="relative bg-black rounded-lg overflow-hidden" style={{ minHeight: 400 }}>
              <CameraStream
                cameraId={camera.id!}
                className="w-full h-auto rounded-lg block"
                onError={(hasError) => setStreamError(hasError)}
                refreshInterval={100}
              />

              {/* LIVE badge */}
              <div className="absolute top-3 left-3 bg-red-600 text-white text-xs px-3 py-1 rounded-full font-bold pointer-events-none">
                LIVE
              </div>

              {/* Zone hint when active */}
              {hasSavedZone && (
                <div className="absolute top-3 right-3 bg-blue-600/90 text-white text-xs px-3 py-1 rounded-full font-medium pointer-events-none">
                  🔵 Safe Zone Monitoring ON
                </div>
              )}
            </div>

            {/* Camera meta */}
            <div className="mt-4 grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
              {[
                { label: 'Camera ID', value: camera.id },
                { label: 'Stream URL', value: camera.rtsp_url, mono: true, truncate: true },
                { label: 'Status', value: camera.status },
                { label: 'Safe Zone', value: hasSavedZone ? `${savedZone.length}-point polygon ✓` : 'Not configured' },
              ].map(m => (
                <div key={m.label} className="bg-gray-50 dark:bg-gray-700 p-3 rounded-lg">
                  <span className="text-gray-500 dark:text-gray-400 text-xs">{m.label}</span>
                  <p className={`mt-1 text-gray-900 dark:text-white ${m.mono ? 'font-mono text-xs' : 'font-medium text-sm'} ${m.truncate ? 'truncate' : ''}`}>
                    {m.value}
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* ── Recent Violations ──────────────────────────────────────────── */}
        {violations.length > 0 && (
          <Card className="dark:bg-gray-800 dark:border-gray-700">
            <CardHeader>
              <CardTitle className="text-gray-900 dark:text-white flex items-center gap-2">
                <AlertTriangle className="h-5 w-5 text-red-500" />
                Recent Violations ({violations.length})
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {violations.map(v => (
                  <div key={v.id} className={`p-3 rounded-lg border ${v.severity === 'high'
                    ? 'border-red-200 bg-red-50 dark:border-red-800 dark:bg-red-900/20'
                    : v.severity === 'medium'
                      ? 'border-amber-200 bg-amber-50 dark:border-amber-800 dark:bg-amber-900/20'
                      : 'border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-700'
                    }`}>
                    <div className="flex justify-between items-start gap-2">
                      <div>
                        <p className="font-medium text-gray-900 dark:text-white">
                          {v.type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}
                        </p>
                        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                          {(v.confidence * 100).toFixed(0)}% confidence · {v.severity.toUpperCase()}
                        </p>
                      </div>
                      <span className="text-xs text-gray-400 flex-shrink-0">{v.detected_at}</span>
                    </div>
                    {v.snapshot_url && (
                      <img
                        src={v.snapshot_url.startsWith('http') ? v.snapshot_url
                          : `${api.getStreamUrl('').split('/api/v1/stream')[0]}${v.snapshot_url}`}
                        alt="Snapshot"
                        className="mt-2 rounded w-full max-w-xs h-auto"
                      />
                    )}
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </>
  );
};

export default LiveView;
