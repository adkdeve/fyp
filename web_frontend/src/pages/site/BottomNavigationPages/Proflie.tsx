import React, { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { User, Mail, Phone, MapPin, Calendar, Loader2 } from 'lucide-react';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { useTheme } from '@/context/ThemeContext';
import { syncSiteOfficerSession, type SiteOfficerSession } from '@/lib/authSession';
import { useToast } from '@/hooks/use-toast';
import { getOfficerById } from '@/lib/firebaseOfficers';
import { doc, updateDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';

function Profile() {
  const { isDarkMode } = useTheme();
  const { toast } = useToast();
  const [session, setSession] = useState<SiteOfficerSession | null>(null);
  const [loading, setLoading] = useState(true);
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [editData, setEditData] = useState({ email: '', phone: '' });

  useEffect(() => {
    syncSiteOfficerSession().then(s => {
      setSession(s);
      if (s) setEditData({ email: s.email || '', phone: s.phone || '' });
      setLoading(false);
    });
  }, []);

  const handleSave = async () => {
    if (!session?.id) return;
    setIsSaving(true);
    try {
      await updateDoc(doc(db, 'officers', session.id), {
        email: editData.email,
        phone: editData.phone,
      });
      // Refresh session to pick up new values
      const updated = await syncSiteOfficerSession();
      setSession(updated);
      setIsEditing(false);
      toast({ title: 'Profile updated', description: 'Your contact information has been saved.' });
    } catch (e) {
      console.error(e);
      toast({ variant: 'destructive', title: 'Error', description: 'Failed to update profile.' });
    } finally {
      setIsSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  const initials = session?.name
    ? session.name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase()
    : '??';

  return (
    <div className="space-y-6">
      <div>
        <h1 className={`text-3xl font-bold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>My Profile</h1>
        <p className={`mt-1 text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
          View and manage your account information
        </p>
      </div>

      {/* Identity Card */}
      <Card className={`shadow-sm overflow-hidden ${isDarkMode ? 'bg-gray-800 border-gray-700' : ''}`}>
        <CardContent className="pt-6">
          <div className="flex flex-col md:flex-row items-start md:items-center gap-6">
            <div className="relative group">
              <Avatar className="h-20 w-20 border-2 border-primary-600 shadow-sm">
                <AvatarFallback className="bg-gradient-to-br from-primary-600 to-primary-400 text-white text-xl font-bold">
                  {initials}
                </AvatarFallback>
              </Avatar>
            </div>

            <div className="flex-1 min-w-0">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div className="min-w-0">
                  <h2 className={`text-2xl font-semibold truncate ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                    {session?.name || 'Unknown Officer'}
                  </h2>
                  <p className={`mt-1 text-sm truncate ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
                    Safety Officer
                  </p>
                </div>
                <Badge className={`px-2 py-1 text-xs ${session?.status === 'active' ? 'bg-green-600 text-white' : 'bg-gray-500 text-white'}`}>
                  {session?.status === 'active' ? 'Active' : 'Inactive'}
                </Badge>
              </div>

              <div className={`mt-4 pt-4 border-t ${isDarkMode ? 'border-gray-700' : 'border-gray-200'}`}>
                <div className="flex flex-wrap items-center gap-6">
                  <div className="flex items-center gap-2">
                    <MapPin className={`h-4 w-4 ${isDarkMode ? 'text-gray-500' : 'text-gray-400'}`} />
                    <div>
                      <p className={`text-xs ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>Sites Assigned</p>
                      <p className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                        {session?.siteIds?.length ?? 0} site(s)
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Calendar className={`h-4 w-4 ${isDarkMode ? 'text-gray-500' : 'text-gray-400'}`} />
                    <div>
                      <p className={`text-xs ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>Login ID</p>
                      <p className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                        {session?.loginId || '—'}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Contact Information */}
      <Card className={`shadow-sm ${isDarkMode ? 'bg-gray-800 border-gray-700' : ''}`}>
        <CardHeader>
          <CardTitle className={`flex items-center gap-2 ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
            <User className="h-5 w-5 text-primary-600" /> Contact Information
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {isEditing ? (
            <>
              <div>
                <label className={`block text-xs font-medium mb-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Email</label>
                <input
                  type="email"
                  value={editData.email}
                  onChange={e => setEditData({ ...editData, email: e.target.value })}
                  className={`w-full px-3 py-2 rounded border text-sm ${isDarkMode ? 'bg-gray-700 border-gray-600 text-white' : 'bg-gray-50 border-gray-300 text-gray-900'} focus:outline-none focus:ring-2 focus:ring-primary-500`}
                />
              </div>
              <div>
                <label className={`block text-xs font-medium mb-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Phone</label>
                <input
                  type="tel"
                  value={editData.phone}
                  onChange={e => setEditData({ ...editData, phone: e.target.value })}
                  className={`w-full px-3 py-2 rounded border text-sm ${isDarkMode ? 'bg-gray-700 border-gray-600 text-white' : 'bg-gray-50 border-gray-300 text-gray-900'} focus:outline-none focus:ring-2 focus:ring-primary-500`}
                />
              </div>
            </>
          ) : (
            <>
              <div className="flex items-center gap-3">
                <Mail className={`h-5 w-5 flex-shrink-0 ${isDarkMode ? 'text-gray-500' : 'text-gray-400'}`} />
                <div>
                  <p className={`text-xs ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>Email</p>
                  <p className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                    {session?.email || '—'}
                  </p>
                </div>
              </div>
              <div className={`border-t ${isDarkMode ? 'border-gray-700' : 'border-gray-200'}`} />
              <div className="flex items-center gap-3">
                <Phone className={`h-5 w-5 flex-shrink-0 ${isDarkMode ? 'text-gray-500' : 'text-gray-400'}`} />
                <div>
                  <p className={`text-xs ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>Phone</p>
                  <p className={`text-sm font-medium ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
                    {session?.phone || '—'}
                  </p>
                </div>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      {/* Actions */}
      <div className="flex gap-3">
        {isEditing ? (
          <>
            <Button
              onClick={handleSave}
              disabled={isSaving}
              className="flex-1 text-white bg-green-600 hover:bg-green-700"
            >
              {isSaving ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving…</> : 'Save Changes'}
            </Button>
            <Button
              onClick={() => { setIsEditing(false); setEditData({ email: session?.email || '', phone: session?.phone || '' }); }}
              disabled={isSaving}
              className="flex-1 text-white bg-gray-500 hover:bg-gray-600"
            >
              Cancel
            </Button>
          </>
        ) : (
          <Button onClick={() => setIsEditing(true)} className="w-full bg-primary-600 hover:bg-primary-700 text-white">
            Edit Profile
          </Button>
        )}
      </div>
    </div>
  );
}

export default Profile;
