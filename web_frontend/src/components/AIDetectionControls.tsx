/**
 * AIDetectionControls — supervisor panel to toggle AI detection modules.
 *
 * Calls the ML service directly to enable/disable:
 *   • PPE Detection (helmet, vest, mask)
 *   • Fire & Smoke Detection
 *   • Face Recognition
 *
 * State is persisted to localStorage and re-synced on mount.
 */
import React, { useEffect, useState, useCallback } from 'react';
import { Switch } from '@/components/ui/switch';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { useToast } from '@/hooks/use-toast';
import { HardHat, Flame, ScanFace, Wifi, WifiOff, Loader2, ShieldAlert, MapPin } from 'lucide-react';
import mlApi, { type DetectionPrefs } from '@/lib/mlApi';

interface ModelState {
  enabled: boolean;
  loading: boolean;
}

interface ServiceStatus {
  online: boolean;
  checked: boolean;
}

const AIDetectionControls: React.FC = () => {
  const { toast } = useToast();

  const saved = mlApi.loadPrefs();
  const [ppe, setPpe] = useState<ModelState>({ enabled: saved.ppe, loading: false });
  const [fire, setFire] = useState<ModelState>({ enabled: saved.fire, loading: false });
  const [face, setFace] = useState<ModelState>({ enabled: saved.face, loading: false });
  const [safeZone, setSafeZone] = useState<ModelState>({ enabled: false, loading: false });
  const [status, setStatus] = useState<ServiceStatus>({ online: false, checked: false });

  // Check if ML service is reachable and sync state
  useEffect(() => {
    let cancelled = false;
    const check = async () => {
      const s = await mlApi.getStatus();
      if (cancelled) return;
      if (s) {
        setStatus({ online: true, checked: true });

        // Re-apply saved prefs to backend on every Settings page open
        // This ensures camera workers get the preferences even after backend restart
        const prefs = mlApi.loadPrefs();
        await mlApi.applyPrefs(prefs);

        // Sync UI from backend's authoritative state
        const am = s.active_models || {};
        setPpe(prev => ({ ...prev, enabled: am.helmet ?? prefs.ppe }));
        setFire(prev => ({ ...prev, enabled: am.firesmoke ?? prefs.fire }));
        setFace(prev => ({ ...prev, enabled: am.face_insight ?? prefs.face }));
        setSafeZone(prev => ({ ...prev, enabled: am.safezone ?? false }));
      } else {
        setStatus({ online: false, checked: true });
      }
    };
    check();
    return () => { cancelled = true; };
  }, []);

  const persistPrefs = useCallback((newPpe: boolean, newFire: boolean, newFace: boolean) => {
    const prefs: DetectionPrefs = { ppe: newPpe, fire: newFire, face: newFace };
    mlApi.savePrefs(prefs);
  }, []);

  const handlePPE = async (value: boolean) => {
    setPpe(s => ({ ...s, loading: true }));
    const ok = await mlApi.togglePPE(value);
    setPpe({ enabled: value, loading: false });
    persistPrefs(value, fire.enabled, face.enabled);
    toast({
      title: value ? '🦺 PPE Detection Enabled' : '🦺 PPE Detection Disabled',
      description: value
        ? 'Helmet, vest, and mask violations will be detected.'
        : 'PPE detection has been turned off.',
      variant: ok ? 'default' : 'destructive',
    });
    if (!ok) setStatus({ online: false, checked: true });
  };

  const handleFire = async (value: boolean) => {
    setFire(s => ({ ...s, loading: true }));
    const ok = await mlApi.toggleFire(value);
    setFire({ enabled: value, loading: false });
    persistPrefs(ppe.enabled, value, face.enabled);
    toast({
      title: value ? '🔥 Fire Detection Enabled' : '🔥 Fire Detection Disabled',
      description: value
        ? 'Fire and smoke will be detected in camera feeds.'
        : 'Fire & smoke detection has been turned off.',
      variant: ok ? 'default' : 'destructive',
    });
    if (!ok) setStatus({ online: false, checked: true });
  };

  const handleFace = async (value: boolean) => {
    setFace(s => ({ ...s, loading: true }));
    const ok = await mlApi.toggleFace(value);
    setFace({ enabled: value, loading: false });
    persistPrefs(ppe.enabled, fire.enabled, value);
    toast({
      title: value ? '👤 Face Recognition Enabled' : '👤 Face Recognition Disabled',
      description: value
        ? 'Unauthorized faces will be flagged in camera feeds.'
        : 'Face recognition has been turned off.',
      variant: ok ? 'default' : 'destructive',
    });
    if (!ok) setStatus({ online: false, checked: true });
  };

  const handleSafeZone = async (value: boolean) => {
    setSafeZone(s => ({ ...s, loading: true }));
    const ok = await mlApi.toggleSafeZone(value);
    setSafeZone({ enabled: value, loading: false });
    toast({
      title: value ? '📍 Safe Zone Monitoring Enabled' : '📍 Safe Zone Monitoring Disabled',
      description: value
        ? 'Persons entering restricted areas will be flagged. Draw zones on camera views.'
        : 'Safe zone monitoring has been turned off.',
      variant: ok ? 'default' : 'destructive',
    });
    if (!ok) setStatus({ online: false, checked: true });
  };

  const models = [
    {
      key: 'ppe',
      label: 'PPE Detection',
      description: 'Detect missing helmets, vests & masks on workers',
      icon: HardHat,
      iconColor: 'text-amber-500',
      bgColor: 'bg-amber-50 dark:bg-amber-900/20',
      state: ppe,
      onToggle: handlePPE,
    },
    {
      key: 'fire',
      label: 'Fire & Smoke Detection',
      description: 'Identify fire or smoke hazards in camera feeds',
      icon: Flame,
      iconColor: 'text-red-500',
      bgColor: 'bg-red-50 dark:bg-red-900/20',
      state: fire,
      onToggle: handleFire,
    },

    {
      key: 'safezone',
      label: 'Safe Zone Monitoring',
      description: 'Detect persons entering restricted zones (draw zones per camera in Live View)',
      icon: MapPin,
      iconColor: 'text-indigo-500',
      bgColor: 'bg-indigo-50 dark:bg-indigo-900/20',
      state: safeZone,
      onToggle: handleSafeZone,
    },
  ];

  return (
    <Card className="shadow-sm dark:bg-gray-800 dark:border-gray-700">
      <CardHeader>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <ShieldAlert className="h-5 w-5 text-indigo-600 dark:text-indigo-400" />
            <CardTitle className="text-gray-900 dark:text-white">AI Detection Controls</CardTitle>
          </div>
          {/* ML service online indicator */}
          {!status.checked ? (
            <span className="flex items-center gap-1.5 text-xs text-gray-400">
              <Loader2 className="h-3 w-3 animate-spin" /> Checking...
            </span>
          ) : status.online ? (
            <span className="flex items-center gap-1.5 text-xs text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/20 px-2 py-0.5 rounded-full font-medium">
              <Wifi className="h-3 w-3" /> ML Service Online
            </span>
          ) : (
            <span className="flex items-center gap-1.5 text-xs text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20 px-2 py-0.5 rounded-full font-medium">
              <WifiOff className="h-3 w-3" /> ML Service Offline
            </span>
          )}
        </div>
        <CardDescription className="text-gray-600 dark:text-gray-400">
          Select which AI models to apply to all incoming camera feeds
        </CardDescription>
      </CardHeader>

      <CardContent className="space-y-1">
        {models.map((m, i) => {
          const Icon = m.icon;
          return (
            <React.Fragment key={m.key}>
              {i > 0 && <div className="border-t border-gray-100 dark:border-gray-700" />}
              <div className="flex items-center justify-between py-3">
                <div className="flex items-center gap-3">
                  <div className={`h-10 w-10 rounded-xl flex items-center justify-center ${m.bgColor}`}>
                    <Icon className={`h-5 w-5 ${m.iconColor}`} />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-white text-sm">{m.label}</p>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{m.description}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2 ml-4 flex-shrink-0">
                  {m.state.loading && (
                    <Loader2 className="h-4 w-4 animate-spin text-gray-400" />
                  )}
                  {/* Show active badge when enabled */}
                  {m.state.enabled && !m.state.loading && (
                    <span className="text-xs text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/20 px-2 py-0.5 rounded-full font-medium">
                      Active
                    </span>
                  )}
                  <Switch
                    id={`ai-toggle-${m.key}`}
                    checked={m.state.enabled}
                    onCheckedChange={m.onToggle}
                    disabled={m.state.loading || !status.checked}
                  />
                </div>
              </div>
            </React.Fragment>
          );
        })}
      </CardContent>
    </Card>
  );
};

export default AIDetectionControls;
