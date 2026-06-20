import React, { useMemo, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useTheme } from '@/context/ThemeContext';
import { useSiteData } from '@/context/SiteDataContext';
import { AlertTriangle, Camera, CheckCircle2, ShieldAlert, Loader2, Download } from 'lucide-react';

// ── helpers ────────────────────────────────────────────────────────────────

function isInRange(isoStr: string, range: 'week' | 'month' | 'year') {
  const d = new Date(isoStr);
  const now = new Date();
  if (range === 'week') {
    const weekAgo = new Date(); weekAgo.setDate(now.getDate() - 7);
    return d >= weekAgo;
  }
  if (range === 'month') {
    const monthAgo = new Date(); monthAgo.setMonth(now.getMonth() - 1);
    return d >= monthAgo;
  }
  // year
  const yearAgo = new Date(); yearAgo.setFullYear(now.getFullYear() - 1);
  return d >= yearAgo;
}

function groupByPeriod(
  violations: any[],
  range: 'week' | 'month' | 'year'
): { labels: string[]; values: number[] } {
  const buckets: Record<string, number> = {};

  violations.forEach(v => {
    const d = new Date(v.detected_at);
    let key: string;
    if (range === 'week') {
      key = d.toLocaleDateString('en-US', { weekday: 'short' });
    } else if (range === 'month') {
      // group by day-of-month
      key = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    } else {
      key = d.toLocaleDateString('en-US', { month: 'short' });
    }
    buckets[key] = (buckets[key] || 0) + 1;
  });

  const labels = Object.keys(buckets);
  const values = labels.map(l => buckets[l]);
  return { labels, values };
}

const VIOLATION_COLORS: Record<string, string> = {
  no_helmet: '#ef4444',
  no_vest:   '#f59e0b',
  no_mask:   '#3b82f6',
  no_gloves: '#8b5cf6',
  no_boots:  '#06b6d4',
  unauthorized_zone: '#ec4899',
  unsafe_material: '#f97316',
};

const sparkPath = (values: number[], w = 120, h = 48) => {
  if (!values.length) return '';
  const max = Math.max(...values, 1);
  const step = w / Math.max(values.length - 1, 1);
  return values
    .map((v, i) => `${Math.round(i * step)},${Math.round(h - (v / max) * h)}`)
    .join(' ');
};

// ── Component ──────────────────────────────────────────────────────────────

const AnalyticsPage = () => {
  const { isDarkMode } = useTheme();
  const { loading, myViolations, openViolations, cameras } = useSiteData();
  const [range, setRange] = useState<'week' | 'month' | 'year'>('week');

  // Filter violations in the selected range
  const filtered = useMemo(
    () => myViolations.filter(v => isInRange(v.detected_at, range)),
    [myViolations, range]
  );

  // Time series data
  const { labels, values } = useMemo(() => groupByPeriod(filtered, range), [filtered, range]);

  // Violation type breakdown
  const typeCounts = useMemo(() => {
    const counts: Record<string, number> = {};
    filtered.forEach(v => { counts[v.type] = (counts[v.type] || 0) + 1; });
    return Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6);
  }, [filtered]);

  const totalFiltered = filtered.length;
  const highCount   = filtered.filter(v => v.severity === 'high').length;
  const mediumCount = filtered.filter(v => v.severity === 'medium').length;
  const lowCount    = filtered.filter(v => v.severity === 'low').length;
  const resolvedCount = filtered.filter(v => v.status !== 'open').length;
  const compliancePct = totalFiltered === 0 ? 100
    : Math.max(0, Math.round(100 - (highCount / (totalFiltered || 1)) * 100));

  // Camera with most violations
  const cameraViolations = useMemo(() => {
    const counts: Record<string, number> = {};
    filtered.forEach(v => {
      counts[v.camera_id] = (counts[v.camera_id] || 0) + 1;
    });
    return Object.entries(counts)
      .map(([id, count]) => {
        const cam = cameras.find(c => c.id === id);
        return { name: cam?.name || id.slice(0, 8), count };
      })
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
  }, [filtered, cameras]);

  const maxBar = Math.max(...values, 1);

  const downloadCSV = () => {
    const rows = filtered.map(v =>
      [v.id, v.type, v.severity, v.status, v.confidence, v.camera_id, v.camera_name || '', v.detected_at].join(',')
    );
    const csv = ['ID,Type,Severity,Status,Confidence,CameraID,CameraName,DetectedAt', ...rows].join('\r\n');
    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `violations_${range}_${new Date().toISOString().split('T')[0]}.csv`;
    a.click(); URL.revokeObjectURL(url);
  };

  const card = `rounded-xl border shadow-sm ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`;
  const txt  = isDarkMode ? 'text-white' : 'text-gray-900';
  const sub  = isDarkMode ? 'text-gray-400' : 'text-gray-500';

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="ml-2 text-gray-500">Loading analytics…</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className={`text-2xl font-bold ${txt}`}>Safety Analytics</h1>
        <div className="flex items-center gap-3">
          <nav className={`flex items-center gap-1 rounded-full p-1 ${isDarkMode ? 'bg-gray-700' : 'bg-gray-100'}`}>
            {(['week', 'month', 'year'] as const).map(r => (
              <button key={r} onClick={() => setRange(r)}
                className={`px-4 py-1.5 rounded-full text-sm font-medium transition capitalize
                  ${range === r
                    ? 'bg-indigo-600 text-white shadow'
                    : isDarkMode ? 'text-gray-300 hover:text-white' : 'text-gray-600 hover:text-gray-900'}`}
              >{r}</button>
            ))}
          </nav>
          <Button variant="outline" size="sm" onClick={downloadCSV}
            className={isDarkMode ? 'text-gray-300 border-gray-600 hover:bg-gray-700' : ''}>
            <Download className="h-4 w-4 mr-1" /> Export CSV
          </Button>
        </div>
      </div>

      {/* Metric Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Total Violations', value: totalFiltered, icon: AlertTriangle, color: 'rose',
            spark: sparkPath(values) },
          { label: 'High Priority',    value: highCount,      icon: ShieldAlert,   color: 'red',
            spark: sparkPath(values.map(v => Math.round(v * highCount / (totalFiltered || 1)))) },
          { label: 'Resolved',         value: resolvedCount,  icon: CheckCircle2,  color: 'green',
            spark: sparkPath(values.map(v => Math.round(v * resolvedCount / (totalFiltered || 1)))) },
          { label: 'Active Cameras',   value: cameras.filter(c => c.enabled).length, icon: Camera, color: 'blue',
            spark: '' },
        ].map(m => {
          const Icon = m.icon;
          const gradients: Record<string, string> = {
            rose:  'from-rose-500 to-pink-500',
            red:   'from-red-500 to-rose-600',
            green: 'from-emerald-500 to-teal-500',
            blue:  'from-sky-500 to-blue-600',
          };
          return (
            <div key={m.label}
              className={`p-4 rounded-xl text-white shadow bg-gradient-to-br ${gradients[m.color]}`}
            >
              <div className="flex justify-between items-start">
                <div>
                  <p className="text-xs opacity-80">{m.label}</p>
                  <p className="text-3xl font-bold mt-1">{m.value}</p>
                </div>
                <Icon className="h-6 w-6 opacity-80" />
              </div>
              {m.spark && (
                <svg className="w-full h-8 mt-2" viewBox="0 0 120 48" fill="none">
                  <polyline
                    points={m.spark}
                    fill="none" stroke="rgba(255,255,255,0.7)" strokeWidth="2.5"
                    strokeLinejoin="round" strokeLinecap="round"
                  />
                </svg>
              )}
            </div>
          );
        })}
      </div>

      {/* Compliance Rate */}
      <div className={`${card} p-5 flex items-center gap-6`}>
        <div className="relative h-24 w-24 flex-shrink-0">
          <svg viewBox="0 0 36 36" className="w-24 h-24 -rotate-90">
            <circle cx="18" cy="18" r="14" fill="none" stroke={isDarkMode ? '#374151' : '#f3f4f6'} strokeWidth="4" />
            <circle cx="18" cy="18" r="14" fill="none"
              stroke={compliancePct >= 80 ? '#10b981' : compliancePct >= 60 ? '#f59e0b' : '#ef4444'}
              strokeWidth="4" strokeLinecap="round"
              strokeDasharray={`${(compliancePct / 100) * 87.96} 87.96`}
            />
          </svg>
          <span className={`absolute inset-0 flex items-center justify-center text-lg font-bold ${txt}`}>
            {compliancePct}%
          </span>
        </div>
        <div>
          <p className={`text-lg font-semibold ${txt}`}>Compliance Rate</p>
          <p className={`text-sm ${sub}`}>Based on {totalFiltered} detection(s) in this period</p>
          <div className="mt-2 flex gap-4 text-xs">
            <span className="text-rose-500 font-medium">{highCount} high</span>
            <span className="text-amber-500 font-medium">{mediumCount} medium</span>
            <span className="text-blue-500 font-medium">{lowCount} low</span>
          </div>
        </div>
      </div>

      {/* Bar Chart + Violation Types */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Bar chart */}
        <div className={`${card} lg:col-span-2 p-5`}>
          <div className="flex items-center justify-between mb-4">
            <p className={`font-semibold ${txt}`}>Violations Over Time</p>
            <span className={`text-xs uppercase tracking-wide ${sub}`}>{range}</span>
          </div>
          {values.length === 0 ? (
            <div className={`flex items-center justify-center h-48 text-sm ${sub}`}>
              No violations in this period
            </div>
          ) : (
            <div className="h-52 flex items-end gap-2 px-2">
              {labels.map((label, i) => {
                const v = values[i] ?? 0;
                const heightPct = Math.max(4, Math.round((v / maxBar) * 100));
                return (
                  <div key={label} className="flex-1 flex flex-col items-center gap-1 h-full">
                    <div className="flex-1 flex items-end w-full justify-center">
                      <div className="relative w-full flex flex-col items-center">
                        <span className={`text-xs font-medium mb-1 ${txt}`}>{v}</span>
                        <div
                          className="w-full max-w-[32px] bg-indigo-500 hover:bg-indigo-400 rounded-t-md transition-all"
                          style={{ height: `${heightPct * 1.6}px` }}
                          title={`${label}: ${v}`}
                        />
                      </div>
                    </div>
                    <span className={`text-xs truncate max-w-[48px] text-center ${sub}`}>{label}</span>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Violation Type Breakdown */}
        <div className={`${card} p-5`}>
          <p className={`font-semibold mb-4 ${txt}`}>Violation Types</p>
          {typeCounts.length === 0 ? (
            <p className={`text-sm ${sub}`}>No data</p>
          ) : (
            <div className="space-y-3">
              {typeCounts.map(([type, count]) => {
                const pct = totalFiltered ? Math.round((count / totalFiltered) * 100) : 0;
                const color = VIOLATION_COLORS[type] || '#6366f1';
                return (
                  <div key={type}>
                    <div className="flex justify-between text-xs mb-1">
                      <span className={`capitalize font-medium ${txt}`}>
                        {type.replace(/_/g, ' ')}
                      </span>
                      <span className={sub}>{count} ({pct}%)</span>
                    </div>
                    <div className={`h-2 rounded-full ${isDarkMode ? 'bg-gray-700' : 'bg-gray-100'}`}>
                      <div
                        className="h-2 rounded-full transition-all"
                        style={{ width: `${pct}%`, background: color }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Top Cameras by Violations */}
      <div className={`${card} p-5`}>
        <p className={`font-semibold mb-4 ${txt}`}>Cameras by Violations</p>
        {cameraViolations.length === 0 ? (
          <p className={`text-sm ${sub}`}>No violations in this period</p>
        ) : (
          <div className="space-y-3">
            {cameraViolations.map(({ name, count }) => {
              const max = cameraViolations[0].count || 1;
              const pct = Math.round((count / max) * 100);
              return (
                <div key={name} className="flex items-center gap-3">
                  <span className={`text-sm w-40 truncate ${txt}`}>{name}</span>
                  <div className={`flex-1 h-2.5 rounded-full ${isDarkMode ? 'bg-gray-700' : 'bg-gray-100'}`}>
                    <div className="h-2.5 rounded-full bg-indigo-500 transition-all" style={{ width: `${pct}%` }} />
                  </div>
                  <span className={`text-sm font-semibold w-6 text-right ${txt}`}>{count}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default AnalyticsPage;
