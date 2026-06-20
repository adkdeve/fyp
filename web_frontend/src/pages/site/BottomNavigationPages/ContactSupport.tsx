import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { useTheme } from '@/context/ThemeContext';
import { useToast } from '@/hooks/use-toast';
import { getSiteOfficerSession } from '@/lib/authSession';
import {
  Send, CheckCircle2, MessageSquare, Phone, Mail,
  X, Loader2, HelpCircle, AlertCircle, Zap, FileText
} from 'lucide-react';

const ISSUE_TYPES = [
  'Camera Not Working',
  'False Alerts',
  'Login / Access Issue',
  'AI Detection Problem',
  'Dashboard / UI Bug',
  'Feature Request',
  'Other',
];

export default function ContactSupport() {
  const { isDarkMode } = useTheme();
  const { toast } = useToast();
  const session = getSiteOfficerSession();

  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState({
    name:      session?.name  || '',
    email:     session?.email || '',
    phone:     session?.phone || '',
    issueType: ISSUE_TYPES[0],
    subject:   '',
    message:   '',
  });
  const [sending, setSending]   = useState(false);
  const [sent,    setSent]      = useState(false);

  const handle = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
    setForm(prev => ({ ...prev, [e.target.name]: e.target.value }));

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.message.trim()) {
      toast({ variant: 'destructive', title: 'Message required', description: 'Please describe your issue.' });
      return;
    }
    setSending(true);
    // Simulate network delay
    setTimeout(() => {
      setSending(false);
      setSent(true);
      toast({ title: '✅ Request submitted', description: 'The support team will get back to you soon.' });
    }, 1400);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSent(false);
    setForm(f => ({ ...f, subject: '', message: '' }));
  };

  const input = `w-full px-3 py-2.5 rounded-lg border text-sm transition outline-none
    focus:ring-2 focus:ring-indigo-500/25 focus:border-indigo-500
    ${isDarkMode
      ? 'bg-gray-700 border-gray-600 text-white placeholder:text-gray-500'
      : 'bg-white border-gray-300 text-gray-900 placeholder:text-gray-400'}`;

  const lbl = `block text-xs font-semibold mb-1.5 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`;

  return (
    <div className="space-y-6 max-w-2xl mx-auto">
      {/* Page header */}
      <div>
        <h1 className={`text-3xl font-bold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
          Help & Support
        </h1>
        <p className={`mt-1 text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
          Find answers or get in touch with the support team
        </p>
      </div>

      {/* Info strip */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {[
          { icon: Mail,         label: 'Email',    value: 'aw2578527@gmail.com' },
          { icon: Phone,        label: 'Phone',    value: 'Available on request' },
          { icon: MessageSquare,label: 'Response', value: 'Within 24 hours' },
        ].map(({ icon: Icon, label: l, value }) => (
          <div key={l} className={`flex items-center gap-3 p-3 rounded-xl border
            ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-gray-50 border-gray-200'}`}
          >
            <div className="h-8 w-8 rounded-lg bg-indigo-100 dark:bg-indigo-900/40 flex items-center justify-center flex-shrink-0">
              <Icon className="h-4 w-4 text-indigo-600 dark:text-indigo-400" />
            </div>
            <div>
              <p className={`text-[10px] uppercase font-semibold tracking-wide ${isDarkMode ? 'text-gray-500' : 'text-gray-400'}`}>{l}</p>
              <p className={`text-sm font-medium ${isDarkMode ? 'text-gray-200' : 'text-gray-800'}`}>{value}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Quick links */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {[
          { icon: AlertCircle, title: 'Understanding Alerts',  desc: 'Learn how to interpret and respond to safety alerts' },
          { icon: Zap,         title: 'Quick Tips',            desc: 'Best practices for using the monitoring system' },
          { icon: FileText,    title: 'Documentation',         desc: 'Complete user guide and technical documentation' },
        ].map(({ icon: Icon, title, desc }) => (
          <Card key={title} className={`cursor-default hover:shadow-md transition ${isDarkMode ? 'bg-gray-800 border-gray-700' : ''}`}>
            <CardContent className="pt-6">
              <Icon className="h-8 w-8 text-indigo-500 mb-3" />
              <h3 className={`font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>{title}</h3>
              <p className={`text-sm mt-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>{desc}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Contact card */}
      <Card className={`border-2 ${isDarkMode ? 'bg-blue-950 border-blue-800' : 'bg-blue-50 border-blue-100'}`}>
        <CardHeader>
          <CardTitle className={`flex items-center gap-2 ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
            <MessageSquare className="h-5 w-5 text-indigo-600" /> Need Help?
          </CardTitle>
          <CardDescription className={isDarkMode ? 'text-gray-400' : 'text-gray-600'}>
            Submit a request and the team will get back to you shortly
          </CardDescription>
        </CardHeader>
        <CardContent>
          <button
            onClick={() => setModalOpen(true)}
            className="w-full py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white font-medium text-sm flex items-center justify-center gap-2 transition"
          >
            <MessageSquare className="h-4 w-4" /> Contact Support
          </button>
        </CardContent>
      </Card>

      {/* ── Modal ─────────────────────────────────────────────────────── */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onClick={closeModal}
          />

          {/* Panel */}
          <div className={`relative w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden
            ${isDarkMode ? 'bg-gray-800' : 'bg-white'}
            animate-in fade-in slide-in-from-bottom-4 duration-200`}
          >
            {/* Header */}
            <div className={`flex items-center justify-between px-6 py-4 border-b
              ${isDarkMode ? 'border-gray-700' : 'border-gray-200'}`}
            >
              <div className="flex items-center gap-2">
                <div className="h-8 w-8 rounded-lg bg-indigo-600 flex items-center justify-center">
                  <HelpCircle className="h-4 w-4 text-white" />
                </div>
                <div>
                  <h2 className={`text-base font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                    Contact Support
                  </h2>
                  <p className={`text-xs ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                    We'll respond within 24 hours
                  </p>
                </div>
              </div>
              <button
                onClick={closeModal}
                className={`p-1.5 rounded-lg transition ${isDarkMode ? 'text-gray-400 hover:bg-gray-700 hover:text-white' : 'text-gray-400 hover:bg-gray-100 hover:text-gray-700'}`}
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Body */}
            <div className="px-6 py-5 max-h-[70vh] overflow-y-auto">
              {sent ? (
                <div className="flex flex-col items-center py-8 gap-3">
                  <CheckCircle2 className="h-14 w-14 text-emerald-500" />
                  <h3 className={`text-lg font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                    Request Submitted!
                  </h3>
                  <p className={`text-sm text-center ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
                    Your message has been received. The support team will get back to you soon.
                  </p>
                  <button
                    onClick={closeModal}
                    className="mt-2 px-6 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition"
                  >
                    Close
                  </button>
                </div>
              ) : (
                <form onSubmit={handleSubmit} className="space-y-4">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label className={lbl}>Your Name</label>
                      <input name="name" value={form.name} onChange={handle}
                        placeholder="Ahmed Khan" className={input} />
                    </div>
                    <div>
                      <label className={lbl}>Email *</label>
                      <input name="email" type="email" value={form.email} onChange={handle}
                        placeholder="you@company.com" className={input} required />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label className={lbl}>Phone (optional)</label>
                      <input name="phone" value={form.phone} onChange={handle}
                        placeholder="+92 300 0000000" className={input} />
                    </div>
                    <div>
                      <label className={lbl}>Issue Type</label>
                      <select name="issueType" value={form.issueType} onChange={handle} className={input}>
                        {ISSUE_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
                      </select>
                    </div>
                  </div>

                  <div>
                    <label className={lbl}>Subject</label>
                    <input name="subject" value={form.subject} onChange={handle}
                      placeholder="Brief summary" className={input} />
                  </div>

                  <div>
                    <label className={lbl}>Message *</label>
                    <textarea name="message" value={form.message} onChange={handle}
                      rows={4} required placeholder="Describe your issue in detail…"
                      className={`${input} resize-none`}
                    />
                  </div>

                  {/* Footer */}
                  <div className="flex gap-3 pt-1">
                    <button type="button" onClick={closeModal}
                      className={`flex-1 py-2.5 rounded-lg border text-sm font-medium transition
                        ${isDarkMode ? 'border-gray-600 text-gray-300 hover:bg-gray-700' : 'border-gray-300 text-gray-700 hover:bg-gray-50'}`}
                    >
                      Cancel
                    </button>
                    <button type="submit" disabled={sending}
                      className="flex-1 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60 text-white text-sm font-medium flex items-center justify-center gap-2 transition"
                    >
                      {sending
                        ? <><Loader2 className="h-4 w-4 animate-spin" /> Sending…</>
                        : <><Send className="h-4 w-4" /> Send Request</>
                      }
                    </button>
                  </div>
                </form>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
