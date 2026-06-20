import React, { useMemo, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Search, Download, Loader2 } from 'lucide-react';
import { useTheme } from '@/context/ThemeContext';
import { useSiteData } from '@/context/SiteDataContext';

type AlertItem = {
  id: string;
  time: string;
  title: string;
  description: string;
  category: string;
  zone?: string;
  status?: 'Active' | 'Resolved' | 'Acknowledged';
  snapshot_url?: string;
};

const categories = ['PPE', 'Hazardous', 'Unauthorized', 'Maintenance', 'Other'];

const HistoryPage: React.FC = () => {
  const { isDarkMode } = useTheme();
  const [query, setQuery] = useState('');
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const { loading, cameras, violations } = useSiteData();

  const toggleCategory = (cat: string) => {
    setSelectedCategories((prev) =>
      prev.includes(cat) ? prev.filter((c) => c !== cat) : [...prev, cat]
    );
  };

  const filtered = useMemo(() => {
    const cameraIds = cameras.map(c => c.id);
    const myViolations = violations.filter(v => cameraIds.includes(v.camera_id));

    const mappedData: AlertItem[] = myViolations.map(v => {
      const isPPE = v.type.includes('helmet') || v.type.includes('vest') || v.type.includes('gloves') || v.type.includes('boots');
      const isHazard = v.type.includes('material');
      const isUnauth = v.type.includes('unauthorized');
      const category = isPPE ? 'PPE' : isHazard ? 'Hazardous' : isUnauth ? 'Unauthorized' : 'Other';

      return {
        id: v.id,
        time: new Date(v.detected_at).toLocaleString(),
        title: v.type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
        description: `Confidence: ${(v.confidence * 100).toFixed(0)}%. Severity: ${v.severity}.`,
        category,
        zone: v.camera_name || 'Camera ' + v.camera_id.substring(0, 6),
        status: v.status === 'open' ? 'Active' : 'Resolved',
        snapshot_url: v.snapshot_url
      };
    });

    const q = query.trim().toLowerCase();
    return mappedData.filter((item) => {
      const matchesQuery =
        !q ||
        item.id.toLowerCase().includes(q) ||
        item.title.toLowerCase().includes(q) ||
        item.description.toLowerCase().includes(q) ||
        item.category.toLowerCase().includes(q);

      const matchesCategory =
        selectedCategories.length === 0 || selectedCategories.includes(item.category);

      return matchesQuery && matchesCategory;
    });
  }, [query, selectedCategories, violations, cameras]);

  if (loading) {
    return (
      <div className={`flex justify-center items-center h-64 ${isDarkMode ? 'text-gray-300' : ''}`}>
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="ml-2">Loading history...</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className={`text-2xl font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>History</h1>
        <div>
          <Link to="/site">
            <Button variant="ghost" size="sm" className={isDarkMode ? 'text-gray-300' : 'text-gray-700'}>Back to Dashboard</Button>
          </Link>
        </div>
      </div>

      <Card className={isDarkMode ? 'bg-gray-800 border-gray-700' : ''}>
        <CardHeader>
          <CardTitle className={isDarkMode ? 'text-white' : 'text-gray-900'}>Activity History</CardTitle>
          <CardDescription className={isDarkMode ? 'text-gray-400' : 'text-gray-600'}>Audit logs and past actions</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
              <Input
                placeholder="Search history, id, description..."
                value={query}
                onChange={(e) => setQuery((e.target as HTMLInputElement).value)}
                className={`max-w-md ${isDarkMode ? 'bg-gray-700 border-gray-600 text-white placeholder:text-gray-400' : ''}`}
              />
              <div className="flex-shrink-0">
                  <Button variant="outline" size="sm" onClick={() => {
                    const API_BASE = (import.meta.env.VITE_API_URL || 'http://localhost:8000').replace(/\/$/, '');
                    const headers = ['ID', 'Time', 'Title', 'Description', 'Category', 'Zone', 'Status', 'Snapshot URL'];
                    const rows = filtered.map(item => {
                      const snapshotFull = item.snapshot_url
                        ? (item.snapshot_url.startsWith('http://') || item.snapshot_url.startsWith('https://')
                            ? item.snapshot_url
                            : `${API_BASE}${item.snapshot_url.startsWith('/') ? item.snapshot_url : '/' + item.snapshot_url}`)
                        : '';
                      return [
                        item.id,
                        `"${item.time}"`,
                        `"${item.title}"`,
                        `"${item.description.replace(/"/g, '""')}"`,
                        item.category,
                        `"${item.zone}"`,
                        item.status ?? '',
                        `"${snapshotFull}"`
                      ].join(',');
                    });
                    const csv = [headers.join(','), ...rows].join('\r\n');
                    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = `violations_history_${new Date().toISOString().split('T')[0]}.csv`;
                    a.click();
                    URL.revokeObjectURL(url);
                  }}>Export CSV</Button>
              </div>
            </div>

            <div>
              <div className={`text-sm font-medium mb-2 ${isDarkMode ? 'text-gray-300' : ''}`}>Categories</div>
              <div className="flex flex-wrap gap-2">
                {categories.map((cat) => {
                  const active = selectedCategories.includes(cat);
                  return (
                    <button
                      key={cat}
                      onClick={() => toggleCategory(cat)}
                      className={`px-3 py-1 rounded-full text-sm border transition-colors ${active ? 'bg-sky-600 text-white border-sky-600' : isDarkMode ? 'bg-gray-700 text-gray-300 border-gray-600' : 'bg-white text-gray-700 border-gray-200'}`}
                    >
                      {cat}
                    </button>
                  );
                })}
                <button
                  onClick={() => setSelectedCategories([])}
                  className={`px-3 py-1 rounded-full text-sm border transition-colors ${isDarkMode ? 'border-gray-600 text-gray-400' : 'border-gray-200 text-gray-600'}`}
                >
                  Clear
                </button>
              </div>
            </div>

            <div>
              <div className="space-y-3">
                {filtered.length === 0 ? (
                  <div className={`p-6 text-center text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>No history found.</div>
                ) : (
                  filtered.map((item, idx) => {
                    // small helpers for badge colors
                    const statusColor =
                      item.status === 'Active' ? 'bg-red-100 text-red-700' :
                      item.status === 'Resolved' ? 'bg-green-100 text-green-700' :
                      'bg-yellow-100 text-yellow-700';

                    const categoryColor =
                      item.category?.toLowerCase().includes('ppe') ? 'bg-sky-50 text-sky-700' :
                      item.category?.toLowerCase().includes('hazard') ? 'bg-amber-50 text-amber-700' :
                      item.category?.toLowerCase().includes('unauthorized') ? 'bg-pink-50 text-pink-700' :
                      'bg-gray-50 text-gray-700';

                    return (
                      <Card key={`${item.id}-${idx}`} className={`w-full rounded-lg border hover:shadow-sm ${isDarkMode ? 'bg-gray-800 border-gray-700' : ''}`}>
                        <CardContent className="flex flex-col gap-4 p-4">
                          <div className="flex items-start justify-between">
                            <div className="flex flex-col gap-2 w-full">
                              <div className="flex items-center gap-2">
                                <span className={`px-2 py-0.5 rounded-full text-xs font-medium border ${categoryColor} border-transparent`}>
                                  {item.category}
                                </span>
                                {item.status && (
                                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium border ${statusColor} border-transparent`}>
                                    {item.status}
                                  </span>
                                )}
                              </div>

                              <div className="mt-1">
                                <h3 className={`text-lg font-semibold leading-tight ${isDarkMode ? 'text-white' : ''}`}>{item.title}</h3>
                              </div>

                              <div className={`flex flex-wrap items-center text-sm gap-4 mt-2 ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                                <span className="flex items-center gap-1">
                                  {/* location icon */}
                                  <svg className="w-4 h-4 text-gray-400" viewBox="0 0 24 24" fill="none" aria-hidden>
                                    <path d="M12 2C8.686 2 6 4.686 6 8c0 5.25 6 12 6 12s6-6.75 6-12c0-3.314-2.686-6-6-6z" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/>
                                    <circle cx="12" cy="8" r="2.2" fill="currentColor"/>
                                  </svg>
                                  <span>{item.zone || 'Unknown zone'}</span>
                                </span>

                                <span className="flex items-center gap-1">
                                  {/* calendar icon */}
                                  <svg className="w-4 h-4 text-gray-400" viewBox="0 0 24 24" fill="none" aria-hidden>
                                    <rect x="3" y="5" width="18" height="16" rx="2" stroke="currentColor" strokeWidth="1.2"/>
                                    <path d="M16 3v4M8 3v4" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/>
                                  </svg>
                                  <span>Today</span>
                                </span>

                                <span className="flex items-center gap-1">
                                  {/* clock icon */}
                                  <svg className="w-4 h-4 text-gray-400" viewBox="0 0 24 24" fill="none" aria-hidden>
                                    <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.2"/>
                                    <path d="M12 7v6l4 2" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/>
                                  </svg>
                                  <span>{item.time.split(' ')[1] || item.time}</span>
                                </span>
                              </div>

                              {item.description && (
                                <p className={`text-sm mt-2 max-w-2xl ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>{item.description}</p>
                              )}
                            </div>
                          </div>

                          {/* full-width rounded bar with centered action (visual match to screenshot) */}
                          <div className="mt-2">
                            <div className={`w-full border rounded-md py-3 px-4 flex justify-center items-center hover:bg-gray-50 dark:hover:bg-gray-600 transition ${isDarkMode ? 'bg-gray-700 border-gray-600' : 'bg-gray-100 border-gray-200'}`}>
                              <Link to={`/site/alert/${item.id}`} className={`flex items-center gap-2 text-sm w-full justify-center ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}>
                                <span className="font-medium">View Full Report</span>
                              </Link>
                            </div>
                          </div>
                        </CardContent>
                      </Card>
                    );
                  })
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default HistoryPage;
