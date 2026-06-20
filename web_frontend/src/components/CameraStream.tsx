/**
 * CameraStream — displays live camera feed by continuously refreshing frames.
 * 
 * Uses the /frame endpoint (single JPEG) with periodic refresh instead of
 * relying on MJPEG multipart/x-mixed-replace which doesn't work reliably in <img> tags.
 */
import React, { useEffect, useRef, useState } from 'react';
import { AlertTriangle } from 'lucide-react';
import api from '@/lib/api';

interface CameraStreamProps {
  cameraId: string;
  className?: string;
  onError?: (error: boolean) => void;
  refreshInterval?: number;  // ms between frame refreshes (default: 100 = ~10fps)
}

const CameraStream: React.FC<CameraStreamProps> = ({
  cameraId,
  className = 'w-full h-auto',
  onError,
  refreshInterval = 100,
}) => {
  const imgRef = useRef<HTMLImageElement>(null);
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(true);
  const intervalRef = useRef<number | null>(null);

  useEffect(() => {
    if (!cameraId) return;

    const frameUrl = api.getFrameUrl(cameraId);

    // Load initial frame
    const loadFrame = () => {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      // Add timestamp to cache-bust
      img.src = `${frameUrl}?t=${Date.now()}`;
      img.onload = () => {
        if (imgRef.current) {
          imgRef.current.src = img.src;
          setError(false);
          setLoading(false);
        }
      };
      img.onerror = () => {
        setError(true);
        setLoading(false);
        onError?.(true);
      };
    };

    loadFrame();

    // Periodically refresh the frame
    intervalRef.current = window.setInterval(loadFrame, refreshInterval);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [cameraId, refreshInterval, onError]);

  if (error) {
    return (
      <div className={`flex flex-col items-center justify-center bg-black rounded-lg ${className}`} style={{ minHeight: 350 }}>
        <AlertTriangle className="h-12 w-12 mb-3 text-yellow-500" />
        <p className="text-gray-400 text-center">Stream Unavailable</p>
      </div>
    );
  }

  return (
    <img
      ref={imgRef}
      alt={`Camera: ${cameraId}`}
      className={className}
      style={{ background: '#000', minHeight: 350 }}
      onError={() => {
        setError(true);
        onError?.(true);
      }}
    />
  );
};

export default CameraStream;
