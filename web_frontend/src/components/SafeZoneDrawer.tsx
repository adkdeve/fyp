/**
 * SafeZoneDrawer — fullscreen canvas modal for drawing a restricted zone polygon
 * on a camera's live feed frame.
 *
 * Approach: renders the live stream in a <canvas> background using drawImage(),
 * refreshed every second so the supervisor sees a near-live frame.
 * Mouse clicks add polygon vertices. Canvas handles all drawing — no SVG/z-index issues.
 */
import React, { useEffect, useRef, useState, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Undo2, Trash2, CheckCircle2, Loader2, X } from 'lucide-react';

// ── Types ─────────────────────────────────────────────────────────────────────
export interface NPoint { nx: number; ny: number; }   // normalized [0,1]

interface Props {
  cameraId: string;                              // camera ID for /frame endpoint
  streamUrl: string;                             // MJPEG stream (shown behind modal)
  cameraName: string;
  initialPoints?: NPoint[];                      // existing polygon (normalized)
  onSave: (points: NPoint[]) => void;
  onClose: () => void;
}

// ── Drawing colours ───────────────────────────────────────────────────────────
const FILL_COLOR   = 'rgba(59,130,246,0.22)';
const STROKE_COLOR = '#3b82f6';
const DOT_FIRST    = '#06b6d4';
const DOT_REST     = '#3b82f6';
const DOT_HOVER    = 'rgba(255,255,255,0.4)';
const CLOSE_THRESH = 18;   // px — snap to first point to close polygon

const SafeZoneDrawer: React.FC<Props> = ({
  cameraId, cameraName, initialPoints = [], onSave, onClose,
}) => {
  // Frame URL: single JPEG, CORS-enabled, refreshed periodically
  const API_URL  = import.meta.env.VITE_API_URL || 'http://localhost:8000';
  const frameUrl = `${API_URL}/api/v1/stream/${cameraId}/frame`;
  const canvasRef  = useRef<HTMLCanvasElement>(null);
  const imgRef     = useRef<HTMLImageElement | null>(null);
  const rafRef     = useRef<number>(0);
  const frameReady = useRef(false);

  // Points in canvas pixel space (converted from normalised on init)
  const [points,   setPoints]   = useState<{ x: number; y: number }[]>([]);
  const [canvasWH, setCanvasWH] = useState({ w: 0, h: 0 });
  const [hoverPos, setHoverPos] = useState<{ x: number; y: number } | null>(null);
  const [closed,   setClosed]   = useState(false);  // polygon closed (≥3 pts, user closed it)
  const [saving,   setSaving]   = useState(false);
  const [loaded,   setLoaded]   = useState(false);

  // ── Load background image once, then keep refreshing ─────────────────────
  const loadFrame = useCallback(() => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.src = `${frameUrl}?t=${Date.now()}`;  // cache-bust for fresh frame
    img.onload = () => {
      imgRef.current = img;
      frameReady.current = true;
      setLoaded(true);
    };
  }, [frameUrl]);

  // Refresh the background frame every 2 seconds (near-live feel)
  useEffect(() => {
    loadFrame();
    const id = setInterval(loadFrame, 2000);
    return () => clearInterval(id);
  }, [loadFrame]);

  // ── Fit canvas to window on mount/resize ─────────────────────────────────
  useEffect(() => {
    const update = () => {
      // Leave room for the toolbar (80px)
      const w = Math.min(window.innerWidth - 32, 1200);
      const h = window.innerHeight - 140;
      setCanvasWH({ w, h });
    };
    update();
    window.addEventListener('resize', update);
    return () => window.removeEventListener('resize', update);
  }, []);

  // ── Convert initial normalised points to canvas pixels when canvas is sized ─
  useEffect(() => {
    if (!canvasWH.w || !canvasWH.h || !initialPoints.length) return;
    setPoints(initialPoints.map(p => ({
      x: p.nx * canvasWH.w,
      y: p.ny * canvasWH.h,
    })));
    if (initialPoints.length >= 3) setClosed(true);
  // Only run when canvas first gets a real size
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canvasWH.w, canvasWH.h]);

  // ── Draw loop ─────────────────────────────────────────────────────────────
  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const { w, h } = canvasWH;
    canvas.width  = w;
    canvas.height = h;

    // Background: camera frame or dark placeholder
    if (frameReady.current && imgRef.current) {
      ctx.drawImage(imgRef.current, 0, 0, w, h);
    } else {
      ctx.fillStyle = '#111';
      ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = '#555';
      ctx.font = '18px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('Loading camera frame…', w / 2, h / 2);
    }

    if (points.length === 0) return;

    // ── Polygon fill (when ≥3 points) ──────────────────────────────────────
    if (points.length >= 3) {
      ctx.beginPath();
      ctx.moveTo(points[0].x, points[0].y);
      for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y);
      ctx.closePath();
      ctx.fillStyle = FILL_COLOR;
      ctx.fill();
    }

    // ── Edges ──────────────────────────────────────────────────────────────
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y);
    if (closed) ctx.closePath();
    ctx.strokeStyle = STROKE_COLOR;
    ctx.lineWidth = 2.5;
    ctx.setLineDash([]);
    ctx.stroke();

    // ── Live edge to hover position (while adding points) ──────────────────
    if (!closed && hoverPos && points.length > 0) {
      ctx.beginPath();
      ctx.moveTo(points[points.length - 1].x, points[points.length - 1].y);
      ctx.lineTo(hoverPos.x, hoverPos.y);
      ctx.strokeStyle = 'rgba(255,255,255,0.5)';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([6, 4]);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // ── Vertex dots ─────────────────────────────────────────────────────────
    points.forEach((p, i) => {
      ctx.beginPath();
      ctx.arc(p.x, p.y, i === 0 ? 9 : 6, 0, 2 * Math.PI);
      ctx.fillStyle = i === 0 ? DOT_FIRST : DOT_REST;
      ctx.fill();
      ctx.strokeStyle = 'white';
      ctx.lineWidth = 2;
      ctx.stroke();

      // Hover ring on first point (close-polygon affordance)
      if (!closed && i === 0 && hoverPos && points.length >= 3) {
        const dist = Math.hypot(hoverPos.x - p.x, hoverPos.y - p.y);
        if (dist < CLOSE_THRESH) {
          ctx.beginPath();
          ctx.arc(p.x, p.y, 16, 0, 2 * Math.PI);
          ctx.strokeStyle = DOT_HOVER;
          ctx.lineWidth = 2;
          ctx.stroke();
        }
      }

      // Point label
      ctx.fillStyle = 'white';
      ctx.font = 'bold 12px sans-serif';
      ctx.shadowColor = 'rgba(0,0,0,0.9)';
      ctx.shadowBlur  = 4;
      ctx.fillText(`${i + 1}`, p.x + 12, p.y - 8);
      ctx.shadowBlur = 0;
    });

    // ── Zone label ─────────────────────────────────────────────────────────
    if (closed && points.length >= 3) {
      const cx = points.reduce((s, p) => s + p.x, 0) / points.length;
      const cy = points.reduce((s, p) => s + p.y, 0) / points.length;
      ctx.fillStyle = 'rgba(59,130,246,0.85)';
      ctx.font = 'bold 14px sans-serif';
      ctx.textAlign = 'center';
      ctx.shadowColor = 'rgba(0,0,0,0.9)';
      ctx.shadowBlur  = 5;
      ctx.fillText('RESTRICTED ZONE', cx, cy);
      ctx.shadowBlur = 0;
      ctx.textAlign = 'left';
    }
  }, [points, canvasWH, hoverPos, closed]);

  // Re-draw on every state change
  useEffect(() => {
    cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  // Also redraw when background frame updates
  useEffect(() => {
    const id = setInterval(() => {
      rafRef.current = requestAnimationFrame(draw);
    }, 500);
    return () => clearInterval(id);
  }, [draw]);

  // ── Pointer handlers ──────────────────────────────────────────────────────
  const getPos = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current!.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  };

  const handleClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (closed) return;
    const pos = getPos(e);

    // Close polygon if clicking near the first point (and ≥3 points placed)
    if (points.length >= 3) {
      const dist = Math.hypot(pos.x - points[0].x, pos.y - points[0].y);
      if (dist < CLOSE_THRESH) {
        setClosed(true);
        return;
      }
    }
    setPoints(prev => [...prev, pos]);
  };

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (closed) return;
    setHoverPos(getPos(e));
  };

  const handleMouseLeave = () => setHoverPos(null);

  const handleUndo = () => {
    if (closed) {
      // Reopen polygon
      setClosed(false);
    } else {
      setPoints(prev => prev.slice(0, -1));
    }
  };

  const handleClear = () => { setPoints([]); setClosed(false); };

  const handleSave = async () => {
    if (!closed && points.length < 3) return;
    if (!closed) setClosed(true);
    setSaving(true);
    try {
      const normalized = points.map(p => ({
        nx: p.x / canvasWH.w,
        ny: p.y / canvasWH.h,
      }));
      await onSave(normalized);
    } finally {
      setSaving(false);
    }
  };

  const canSave = (closed || points.length >= 3);

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    /* Fullscreen backdrop */
    <div
      style={{
        position: 'fixed', inset: 0, zIndex: 9999,
        background: 'rgba(0,0,0,0.92)',
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        justifyContent: 'flex-start', padding: '16px',
        overflowY: 'auto',
      }}
    >
      {/* ── Toolbar ─────────────────────────────────────────────────────── */}
      <div style={{
        width: '100%', maxWidth: 1200,
        display: 'flex', alignItems: 'center', gap: 12,
        marginBottom: 12, flexWrap: 'wrap',
      }}>
        {/* Title */}
        <div style={{ flex: 1 }}>
          <p style={{ color: 'white', fontWeight: 700, fontSize: 16, margin: 0 }}>
            Draw Safe Zone — {cameraName}
          </p>
          <p style={{ color: '#94a3b8', fontSize: 12, margin: '2px 0 0' }}>
            {!closed
              ? points.length < 3
                ? `Click on the video to place boundary points (${Math.max(0, 3 - points.length)} more needed)`
                : 'Continue adding points, or click the first point (cyan) to close the polygon'
              : `${points.length}-point polygon drawn · click Save Zone to confirm`}
          </p>
        </div>

        {/* Actions */}
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          {points.length > 0 && (
            <Button size="sm" variant="ghost"
              onClick={handleUndo}
              style={{ color: '#94a3b8', border: '1px solid #334155' }}>
              <Undo2 style={{ width: 14, height: 14, marginRight: 4 }} />
              {closed ? 'Reopen' : 'Undo'}
            </Button>
          )}
          {points.length > 0 && (
            <Button size="sm" variant="ghost"
              onClick={handleClear}
              style={{ color: '#f87171', border: '1px solid #334155' }}>
              <Trash2 style={{ width: 14, height: 14, marginRight: 4 }} />
              Clear
            </Button>
          )}
          <Button size="sm"
            onClick={handleSave}
            disabled={!canSave || saving}
            style={{
              background: canSave ? '#2563eb' : '#1e3a5f',
              color: 'white',
              opacity: canSave ? 1 : 0.5,
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
            {saving
              ? <Loader2 style={{ width: 14, height: 14, animation: 'spin 1s linear infinite' }} />
              : <CheckCircle2 style={{ width: 14, height: 14 }} />}
            Save Zone
          </Button>
          <Button size="sm" variant="ghost"
            onClick={onClose}
            style={{ color: '#94a3b8', border: '1px solid #334155' }}>
            <X style={{ width: 14, height: 14, marginRight: 4 }} />
            Cancel
          </Button>
        </div>
      </div>

      {/* ── Canvas ─────────────────────────────────────────────────────────── */}
      <div style={{ position: 'relative', lineHeight: 0 }}>
        {!loaded && (
          <div style={{
            position: 'absolute', inset: 0, zIndex: 1,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Loader2 style={{ color: '#3b82f6', width: 40, height: 40,
              animation: 'spin 1s linear infinite' }} />
          </div>
        )}
        <canvas
          ref={canvasRef}
          width={canvasWH.w}
          height={canvasWH.h}
          onClick={handleClick}
          onMouseMove={handleMouseMove}
          onMouseLeave={handleMouseLeave}
          style={{
            cursor: closed ? 'default' : 'crosshair',
            borderRadius: 8,
            border: '2px solid #1e40af',
            display: 'block',
            maxWidth: '100%',
          }}
        />
      </div>

      {/* ── Legend ─────────────────────────────────────────────────────────── */}
      <div style={{
        display: 'flex', gap: 20, marginTop: 12,
        color: '#94a3b8', fontSize: 12, flexWrap: 'wrap', justifyContent: 'center',
      }}>
        <span>🔵 Click to place points</span>
        <span>🔵 Click the cyan dot to close the polygon</span>
        <span>↩ Undo removes the last point</span>
        <span>✅ Need ≥ 3 points to save</span>
      </div>
    </div>
  );
};

export default SafeZoneDrawer;
