import { Link } from 'react-router-dom';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useTheme } from '@/context/ThemeContext';
import { AlertTriangle, Video, Camera, ShieldCheck, CheckCircle, Loader2 } from 'lucide-react';
import { useSiteData } from '@/context/SiteDataContext';
import api from '@/lib/api';
import { useState } from 'react';
import AIDetectionControls from '@/components/AIDetectionControls';


const CompanyDashboard = () => {
  const { isDarkMode } = useTheme();
  const { loading, sites, cameras, myViolations, openViolations } = useSiteData();

  const enabledCameras = cameras.filter(c => c.enabled);
  // Track per-camera stream error state
  const [streamErrors, setStreamErrors] = useState<Record<string, boolean>>({});
  const markError = (id: string) => setStreamErrors(prev => ({ ...prev, [id]: true }));
  const markLoad  = (id: string) => setStreamErrors(prev => ({ ...prev, [id]: false }));

  if (loading) {
    return (
      <div className={`flex justify-center items-center h-64 ${isDarkMode ? 'text-gray-300' : ''}`}>
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="ml-2">Loading dashboard data…</p>
      </div>
    );
  }

  const nowStr = new Date().toLocaleString(undefined, {
    weekday: 'long', month: 'long', day: 'numeric',
    year: 'numeric', hour: '2-digit', minute: '2-digit'
  });

  const metrics = [
    { title: 'Assigned Sites',    value: sites.length,           icon: ShieldCheck, tone: 'teal' },
    { title: 'Active Violations', value: openViolations.length,  icon: AlertTriangle, tone: 'rose',
      subtitle: openViolations.length > 0 ? 'Requires attention' : 'All clear' },
    { title: 'Total Cameras',     value: cameras.length,         icon: Camera, tone: 'blue',
      subtitle: `${enabledCameras.length} enabled` },
    { title: 'Total Detections',  value: myViolations.length,    icon: CheckCircle, tone: 'indigo' },
  ];

  return (
    <div className="space-y-8">
      {/* Hero */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <h1 className={`text-2xl md:text-3xl font-extrabold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
            Dashboard Overview
          </h1>
          <p className={`mt-1 text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>{nowStr}</p>
        </div>
        <span className={`px-4 py-2 rounded-full text-sm ${isDarkMode ? 'bg-emerald-900/40 text-emerald-400' : 'bg-emerald-50 text-emerald-700'}`}>
          System Active
        </span>
      </div>

      {/* Metric cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {metrics.map(m => {
          const Icon = m.icon;
          const toneBg   = m.tone === 'teal'   ? isDarkMode ? 'bg-emerald-900/30' : 'bg-emerald-50'
                         : m.tone === 'rose'   ? isDarkMode ? 'bg-rose-900/30'    : 'bg-rose-50'
                         : m.tone === 'blue'   ? isDarkMode ? 'bg-sky-900/30'     : 'bg-sky-50'
                         :                       isDarkMode ? 'bg-indigo-900/30'  : 'bg-indigo-50';
          const textTone = m.tone === 'teal'   ? isDarkMode ? 'text-emerald-400'  : 'text-emerald-600'
                         : m.tone === 'rose'   ? isDarkMode ? 'text-rose-400'     : 'text-rose-500'
                         : m.tone === 'blue'   ? isDarkMode ? 'text-sky-400'      : 'text-sky-600'
                         :                       isDarkMode ? 'text-indigo-400'   : 'text-indigo-600';
          return (
            <div key={m.title} className={`rounded-xl p-4 shadow-sm border ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className={`text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>{m.title}</div>
                  <div className={`mt-2 text-3xl font-bold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>{m.value}</div>
                  {m.subtitle && <div className={`text-xs mt-1 ${isDarkMode ? 'text-gray-500' : 'text-gray-500'}`}>{m.subtitle}</div>}
                </div>
                <div className={`h-12 w-12 rounded-xl flex items-center justify-center ${toneBg}`}>
                  <Icon className={`h-6 w-6 ${textTone}`} />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* AI Detection Controls */}
      <AIDetectionControls />

      {/* Live feeds + Recent alerts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Camera Feeds */}
        <div className="lg:col-span-2 space-y-4">
          <div className="flex items-center gap-2">
            <Video className="h-5 w-5 text-blue-600" />
            <h2 className={`text-lg font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>Live Camera Feeds</h2>
          </div>

          {cameras.length === 0 ? (
            <div className={`text-center py-8 rounded-xl border ${isDarkMode ? 'bg-gray-800 border-gray-700 text-gray-400' : 'bg-white border-gray-200 text-gray-500'}`}>
              No cameras assigned to your sites.
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {cameras.map(cam => (
                <Link key={cam.id} to={`/site/camera/${cam.id}`}
                  className={`block rounded-xl border p-3 hover:shadow-lg transition ${isDarkMode ? 'border-gray-700 bg-gray-800 hover:border-gray-600' : 'border-gray-200 bg-white hover:border-indigo-200'}`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <div>
                      <div className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>{cam.name}</div>
                      <div className={`text-xs ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>{cam.location}</div>
                    </div>
                    <span className={`text-xs px-2 py-1 rounded-full text-white ${cam.enabled ? 'bg-emerald-600' : 'bg-gray-400'}`}>
                      {cam.enabled ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                  {/* Camera preview */}
                  <div className={`rounded-lg h-40 relative overflow-hidden border ${isDarkMode ? 'bg-gray-900 border-gray-600' : 'bg-gray-100 border-gray-200'}`}>
                    {cam.enabled && (
                      <img
                        src={api.getStreamUrl(cam.id!)}
                        alt={cam.name}
                        className="w-full h-full object-cover"
                        onLoad={() => markLoad(cam.id!)}
                        onError={() => markError(cam.id!)}
                      />
                    )}
                    {/* Badge: LIVE only when stream is good, OFFLINE otherwise */}
                    {cam.enabled && !streamErrors[cam.id!] ? (
                      <div className="absolute left-3 top-3 bg-red-600 text-white text-xs px-2 py-0.5 rounded-full font-bold flex items-center gap-1">
                        <span className="h-1.5 w-1.5 rounded-full bg-white animate-pulse" />
                        LIVE
                      </div>
                    ) : (
                      <div className="absolute left-3 top-3 bg-gray-600 text-white text-xs px-2 py-0.5 rounded-full font-bold">
                        OFFLINE
                      </div>
                    )}
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>

        {/* Recent alerts */}
        <div className="space-y-4">
          <h2 className={`text-lg font-semibold flex items-center gap-2 ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
            <AlertTriangle className="h-5 w-5 text-rose-500" /> Recent Alerts
          </h2>

          {myViolations.length === 0 ? (
            <div className={`text-center py-6 rounded-xl border ${isDarkMode ? 'bg-gray-800 border-gray-700 text-gray-400' : 'bg-white border-gray-200 text-gray-500'}`}>
              No violations detected yet.
            </div>
          ) : (
            <div className="space-y-2">
              {myViolations.slice(0, 3).map(v => (
                <Link key={v.id} to={`/site/alert/${v.id}`}
                  className={`block rounded-lg p-3 border transition hover:shadow-sm ${
                    v.severity === 'high'   ? isDarkMode ? 'border-rose-800 bg-rose-900/20 hover:bg-rose-900/30'     : 'border-rose-200 bg-rose-50 hover:bg-rose-100' :
                    v.severity === 'medium' ? isDarkMode ? 'border-amber-800 bg-amber-900/20 hover:bg-amber-900/30'  : 'border-amber-200 bg-amber-50 hover:bg-amber-100' :
                                              isDarkMode ? 'border-blue-800 bg-blue-900/20'                          : 'border-blue-200 bg-blue-50'
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                        {v.type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}
                      </div>
                      <div className={`text-xs ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                        {v.camera_name || v.camera_id.slice(0, 8)} · {(v.confidence * 100).toFixed(0)}% confidence
                      </div>
                    </div>
                    <span className={`text-xs px-2 py-1 rounded-full text-white flex-shrink-0 ${
                      v.severity === 'high' ? 'bg-rose-600' : v.severity === 'medium' ? 'bg-amber-500' : 'bg-blue-600'
                    }`}>
                      {v.severity}
                    </span>
                  </div>
                </Link>
              ))}
            </div>
          )}

          <Card className={isDarkMode ? 'bg-gray-800 border-gray-700' : ''}>
            <CardHeader className="pb-2">
              <CardTitle className={`text-sm ${isDarkMode ? 'text-white' : ''}`}>Activity Summary</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className={`flex items-center justify-between ${isDarkMode ? 'text-gray-300' : ''}`}>
                <span className="text-sm opacity-80">Total Detections</span>
                <span className={`text-lg font-bold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>{myViolations.length}</span>
              </div>
              <div className={`flex items-center justify-between ${isDarkMode ? 'text-gray-300' : ''}`}>
                <span className="text-sm opacity-80">Open Issues</span>
                <span className="text-lg font-bold text-rose-500">{openViolations.length}</span>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default CompanyDashboard;