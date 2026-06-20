import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import {
  AlertTriangle, Camera, ArrowLeft, CameraIcon, Download,
  Clock, MapPin, Lightbulb, Loader2, HardHat, ShieldAlert, Eye, CheckCircle2
} from 'lucide-react';
import { getViolationById, type ViolationRecord } from '@/lib/firebaseViolations';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

function buildSnapshotUrl(snapshot_url?: string): string | null {
  if (!snapshot_url) return null;
  // Firebase Storage URLs are already fully qualified — use as-is
  if (snapshot_url.startsWith('http://') || snapshot_url.startsWith('https://')) {
    return snapshot_url;
  }
  // Legacy: relative path saved by old local-file approach
  const base = API_URL.endsWith('/') ? API_URL.slice(0, -1) : API_URL;
  const path = snapshot_url.startsWith('/') ? snapshot_url : '/' + snapshot_url;
  return `${base}${path}`;
}

// ── Per-violation recommended actions ──────────────────────────────────────
const RECOMMENDED_ACTIONS: Record<string, { icon: React.ReactNode; steps: string[] }> = {
  no_helmet: {
    icon: <HardHat className="h-5 w-5 text-rose-600" />,
    steps: [
      'Immediately stop the worker and ask them to put on an approved hard hat before re-entering the zone.',
      'Issue a verbal warning and log it in the daily safety register.',
      'Inspect the helmet store to ensure an adequate supply of approved hard hats is available.',
      'If this is a repeat offence, escalate to a formal written warning per site safety policy.',
      'Conduct a team toolbox talk on head-protection requirements before the next shift.',
    ],
  },
  no_vest: {
    icon: <ShieldAlert className="h-5 w-5 text-amber-600" />,
    steps: [
      'Direct the worker to wear a high-visibility safety vest before continuing work.',
      'Check that vests in the site store meet EN ISO 20471 (or local equivalent) Class 2 or higher.',
      'Record the incident in the safety log and notify the site supervisor.',
      'Review the on-boarding checklist to ensure PPE issuance is completed for all new workers.',
      'Consider posting reminder signage at all site entry points.',
    ],
  },
  no_mask: {
    icon: <Eye className="h-5 w-5 text-blue-600" />,
    steps: [
      'Ask the worker to wear an approved dust / respiratory mask, especially in dusty or chemically hazardous areas.',
      'Verify that the correct mask grade is available (e.g., FFP2/N95 for fine dust).',
      'Log the observation and speak to the worker about respiratory risks.',
      'Check if the area requires mandatory respiratory protection and update the site risk assessment if needed.',
    ],
  },
  no_gloves: {
    icon: <ShieldAlert className="h-5 w-5 text-amber-600" />,
    steps: [
      'Remind the worker to wear appropriate gloves for the task being performed.',
      'Ensure the correct glove type is available (cut-resistant, chemical, thermal, etc.).',
      'Record the observation and brief the crew on hand-injury statistics.',
    ],
  },
  no_boots: {
    icon: <ShieldAlert className="h-5 w-5 text-amber-600" />,
    steps: [
      'Require the worker to wear steel-toe or composite-toe safety boots before entering the work area.',
      'Confirm that the boots meet the site minimum safety footwear standard.',
      'Log the incident and notify the site safety officer.',
    ],
  },
  unauthorized_zone: {
    icon: <AlertTriangle className="h-5 w-5 text-rose-600" />,
    steps: [
      'Immediately escort the unauthorised individual out of the restricted zone.',
      'Review and reinforce access control procedures (barriers, signage, access cards).',
      'Report the breach to the site security and safety manager.',
      'Investigate how entry was gained and fix any gaps in the perimeter.',
      'Conduct a safety briefing to remind all personnel of restricted-zone boundaries.',
    ],
  },
  unsafe_material: {
    icon: <AlertTriangle className="h-5 w-5 text-rose-600" />,
    steps: [
      'Isolate the area and prevent access until the hazardous material is secured or removed.',
      'Notify the site safety officer and, if applicable, the environment/health and safety authority.',
      'Follow the site\'s hazardous-material emergency procedure (MSDS / SDS sheet).',
      'Document the incident and conduct a root-cause analysis to prevent recurrence.',
    ],
  },
};

const DEFAULT_ACTIONS = {
  icon: <CheckCircle2 className="h-5 w-5 text-blue-600" />,
  steps: [
    'Review the snapshot and identify the specific safety violation.',
    'Contact the relevant worker or crew and correct the unsafe behaviour immediately.',
    'Log the incident in the site safety register.',
    'Ensure corrective action is taken before allowing work to continue.',
  ],
};

function getRecommendedActions(type: string) {
  return RECOMMENDED_ACTIONS[type] ?? DEFAULT_ACTIONS;
}

// ── Formatted PDF-style report ─────────────────────────────────────────────
async function downloadFormattedReport(alert: ViolationRecord) {
  const snapshotUrl = buildSnapshotUrl(alert.snapshot_url);
  const actions = getRecommendedActions(alert.type);

  const stepsHtml = actions.steps
    .map((s, i) => `<li style="margin-bottom:6px;"><b>Step ${i + 1}:</b> ${s}</li>`)
    .join('');

  // Fetch image and convert to base64 so it shows up in local HTML file
  let snapshotSection = `<div style="padding:24px;background:#f3f4f6;border-radius:8px;text-align:center;color:#9ca3af;margin:24px 0;">
       No snapshot available
     </div>`;

  if (snapshotUrl) {
    try {
      const resp = await fetch(snapshotUrl);
      const blob = await resp.blob();
      const dataUrl = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result as string);
        reader.onerror = reject;
        reader.readAsDataURL(blob);
      });
      snapshotSection = `<div style="text-align:center;margin:24px 0;">
         <img src="${dataUrl}" alt="Violation Snapshot"
              style="max-width:100%;max-height:400px;border:2px solid #e5e7eb;border-radius:8px;" />
         <p style="font-size:12px;color:#6b7280;margin-top:6px;">Figure 1 – Violation snapshot captured at detection time</p>
       </div>`;
    } catch {
      snapshotSection = `<div style="padding:24px;background:#fff3cd;border-radius:8px;text-align:center;color:#856404;margin:24px 0;">
         Snapshot could not be embedded (server may be offline).<br/>
         <a href="${snapshotUrl}" style="color:#0d6efd;">View snapshot online</a>
       </div>`;
    }
  }


  const severityColor =
    alert.severity === 'high' ? '#dc2626' :
    alert.severity === 'medium' ? '#d97706' : '#2563eb';

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <title>Violation Report – ${alert.id}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', Arial, sans-serif; color: #111827; background: #fff; padding: 40px; max-width: 860px; margin: auto; }
    h1  { font-size: 26px; font-weight: 700; color: #111827; }
    h2  { font-size: 17px; font-weight: 600; margin-bottom: 12px; color: #374151; border-bottom: 2px solid #e5e7eb; padding-bottom: 6px; }
    .header-row { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 28px; }
    .badge { display: inline-block; padding: 5px 14px; border-radius: 9999px; color: #fff; font-size: 13px; font-weight: 700; background: ${severityColor}; }
    .section { margin-bottom: 28px; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
    .cell { background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 8px; padding: 14px; }
    .cell-label { font-size: 11px; color: #6b7280; text-transform: uppercase; letter-spacing: .5px; }
    .cell-value { font-size: 15px; font-weight: 600; margin-top: 4px; color: #111827; }
    ul { list-style: none; padding: 0; }
    li { background: #f9fafb; border-left: 4px solid ${severityColor}; border-radius: 4px; padding: 10px 14px; margin-bottom: 8px; font-size: 14px; color: #374151; }
    .footer { margin-top: 40px; font-size: 11px; color: #9ca3af; text-align: center; border-top: 1px solid #e5e7eb; padding-top: 16px; }
  </style>
</head>
<body>
  <div class="header-row">
    <div>
      <h1>🦺 Safety Violation Report</h1>
      <p style="margin-top:6px;color:#6b7280;font-size:13px;">Report ID: <code>${alert.id}</code></p>
    </div>
    <span class="badge">${alert.severity.toUpperCase()} PRIORITY</span>
  </div>

  <div class="section">
    <h2>Incident Summary</h2>
    <div class="grid">
      <div class="cell"><div class="cell-label">Violation Type</div><div class="cell-value">${alert.type.replace(/_/g, ' ').toUpperCase()}</div></div>
      <div class="cell"><div class="cell-label">Severity</div><div class="cell-value" style="color:${severityColor}">${alert.severity.toUpperCase()}</div></div>
      <div class="cell"><div class="cell-label">AI Confidence</div><div class="cell-value">${(alert.confidence * 100).toFixed(0)}%</div></div>
      <div class="cell"><div class="cell-label">Status</div><div class="cell-value">${alert.status.toUpperCase()}</div></div>
      <div class="cell"><div class="cell-label">Camera</div><div class="cell-value">${alert.camera_name || alert.camera_id}</div></div>
      <div class="cell"><div class="cell-label">Detected At</div><div class="cell-value">${new Date(alert.detected_at).toLocaleString()}</div></div>
    </div>
  </div>

  <div class="section">
    <h2>Snapshot Evidence</h2>
    ${snapshotSection}
  </div>

  <div class="section">
    <h2>Recommended Corrective Actions</h2>
    <ul>${stepsHtml}</ul>
  </div>

  <div class="footer">
    Generated automatically by Construction Safety Platform &nbsp;•&nbsp; ${new Date().toLocaleString()}
  </div>
</body>
</html>`;

  const blob = new Blob([html], { type: 'text/html' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `violation_report_${alert.id}.html`;
  a.click();
  URL.revokeObjectURL(url);
}

// ─────────────────────────────────────────────────────────────────────────────

export default function VoilationDetails() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [alert, setAlert] = useState<ViolationRecord | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!id) return;
    getViolationById(id).then(data => {
      setAlert(data);
      setLoading(false);
    }).catch(err => {
      console.error(err);
      setLoading(false);
    });
  }, [id]);

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="ml-2">Loading details...</p>
      </div>
    );
  }

  const snapshotUrl = buildSnapshotUrl(alert?.snapshot_url);
  const actions = alert ? getRecommendedActions(alert.type) : DEFAULT_ACTIONS;

  const severityBg =
    alert?.severity === 'high'   ? 'bg-rose-600' :
    alert?.severity === 'medium' ? 'bg-amber-500' : 'bg-blue-600';

  const actionsBorderBg =
    alert?.severity === 'high'   ? 'border-rose-200 bg-rose-50' :
    alert?.severity === 'medium' ? 'border-amber-200 bg-amber-50' : 'border-blue-200 bg-blue-50';

  return (
    <div className="space-y-6 px-4 md:px-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Button variant="link" size="sm" onClick={() => navigate(-1)} className="text-gray-700">
            <ArrowLeft />
          </Button>
          <div>
            <h1 className="text-2xl font-semibold text-gray-900">
              {alert ? alert.type.replace(/_/g, ' ').toUpperCase() : 'Alert details'}
            </h1>
            <div className="text-sm text-gray-600">
              {alert
                ? `${alert.camera_name || alert.camera_id} • ${new Date(alert.detected_at).toLocaleString()}`
                : 'No details available'}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className={`text-sm px-3 py-1 rounded-full text-white ${severityBg}`}>
            {alert?.severity.toUpperCase() ?? 'N/A'}
          </span>
          <Link to="/site/allcameras">
            <Button variant="ghost" size="sm" className="text-gray-700">
              <Camera className="mr-2 h-4 w-4" /> Open Cameras
            </Button>
          </Link>
        </div>
      </div>

      {/* Violation Details Card */}
      <Card>
        <CardHeader>
          <CardTitle className="text-gray-900">Violation Details</CardTitle>
          <CardDescription className="text-gray-600">
            {alert ? `AI Confidence: ${(alert.confidence * 100).toFixed(0)}%` : 'No record found'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {alert ? (
            <div className="space-y-4">
              {/* Snapshot */}
              <div className="rounded-md overflow-hidden border border-gray-200 bg-black flex items-center justify-center">
                {snapshotUrl ? (
                  <img
                    src={snapshotUrl}
                    alt="Violation Snapshot"
                    className="w-full h-auto max-h-[500px] object-contain"
                  />
                ) : (
                  <div className="text-gray-400 p-12">No snapshot available</div>
                )}
              </div>

              {/* Metadata grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="rounded-lg p-4 border border-gray-200 bg-white">
                  <div className="text-xs text-gray-600 flex items-center gap-1">
                    <MapPin className="h-4 w-4" /> Location
                  </div>
                  <div className="font-medium text-gray-900 mt-2">{alert.camera_name || 'Unknown'}</div>
                </div>

                <div className="rounded-lg p-4 border border-gray-200 bg-white">
                  <div className="text-xs text-gray-600 flex items-center gap-1">
                    <Clock className="h-4 w-4" /> Timestamp
                  </div>
                  <div className="font-medium text-gray-900 mt-2">
                    {new Date(alert.detected_at).toLocaleString()}
                  </div>
                </div>

                <div className="rounded-lg p-4 border border-gray-200 bg-white">
                  <div className="text-xs text-gray-600 flex items-center gap-1">
                    <CameraIcon className="h-4 w-4" /> Camera ID
                  </div>
                  <div className="font-medium text-gray-900 mt-2">{alert.camera_id}</div>
                </div>

                <div className="rounded-lg p-4 border border-gray-200 bg-white">
                  <div className="text-xs text-gray-600">Detection Info</div>
                  <div className="font-medium text-gray-900 mt-2">
                    {alert.type.replace(/_/g, ' ').toUpperCase()} ({(alert.confidence * 100).toFixed(0)}%)
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="text-sm text-slate-400">Alert not found. Return to alerts list.</div>
          )}
        </CardContent>
      </Card>

      {/* Recommended Actions Card */}
      {alert && (
        <Card className={`border ${actionsBorderBg}`}>
          <CardHeader>
            <CardTitle className="text-gray-900 flex items-center gap-2">
              <Lightbulb className="h-5 w-5 text-amber-500" />
              Recommended Actions
              <span className={`ml-auto text-xs px-2 py-1 rounded-full text-white ${severityBg}`}>
                {alert.severity.toUpperCase()} PRIORITY
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <ol className="space-y-3">
              {actions.steps.map((step, i) => (
                <li key={i} className="flex items-start gap-3">
                  <span className={`flex-shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-white text-xs font-bold ${severityBg}`}>
                    {i + 1}
                  </span>
                  <p className="text-gray-700 text-sm leading-relaxed">{step}</p>
                </li>
              ))}
            </ol>
          </CardContent>
        </Card>
      )}

      {/* Download */}
      <Card>
        <CardContent>
          <div className="flex items-center justify-center gap-4 mx-auto pt-6">
            <button
              onClick={() => alert && downloadFormattedReport(alert)}
              className="bg-blue-600 text-white rounded-md flex-1 py-2 flex items-center justify-center hover:bg-blue-700 transition"
            >
              <Download className="mr-2 h-4 w-4" /> Download Report
            </button>
          </div>
          <p className="text-center text-xs text-gray-400 mt-2">
            Downloads an HTML report with snapshot and recommended corrective actions
          </p>
        </CardContent>
      </Card>
    </div>
  );
}