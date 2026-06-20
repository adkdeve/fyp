import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Bell, Eye } from 'lucide-react';
import { useTheme } from '@/context/ThemeContext';
import { useToast } from '@/hooks/use-toast';
import AIDetectionControls from '@/components/AIDetectionControls';


// Persist notification preferences in localStorage
const NOTIF_KEY = 'site_notif_prefs';

function loadPrefs() {
  try {
    const raw = localStorage.getItem(NOTIF_KEY);
    if (raw) return JSON.parse(raw);
  } catch { }
  return { alerts: true, sound: false };
}

function savePrefs(prefs: { alerts: boolean; sound: boolean }) {
  localStorage.setItem(NOTIF_KEY, JSON.stringify(prefs));
}

function Settings() {
  const { isDarkMode, toggleDarkMode } = useTheme();
  const { toast } = useToast();

  const initial = loadPrefs();
  const [alerts, setAlerts] = useState<boolean>(initial.alerts);
  const [sound, setSound] = useState<boolean>(initial.sound);

  const handleAlerts = (val: boolean) => {
    setAlerts(val);
    savePrefs({ alerts: val, sound });
    toast({
      title: val ? 'Alert notifications enabled' : 'Alert notifications disabled',
      description: val
        ? 'You will see in-app pop-ups for new PPE violations.'
        : 'In-app violation pop-ups have been turned off.',
    });
  };

  const handleSound = (val: boolean) => {
    setSound(val);
    savePrefs({ alerts, sound: val });
    toast({
      title: val ? 'Sound alerts enabled' : 'Sound alerts disabled',
      description: val
        ? 'A sound will play for critical violation pop-ups.'
        : 'Sound for violation pop-ups has been turned off.',
    });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Settings</h1>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Manage your preferences and account settings
        </p>
      </div>

      {/* AI Detection Controls — supervisor only */}
      <AIDetectionControls />


      <Card className="shadow-sm dark:bg-gray-800 dark:border-gray-700">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-gray-900 dark:text-white">
            <Bell className="h-5 w-5 text-primary-600" /> Notifications
          </CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            Control how you receive in-app updates
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Alert pop-ups — controls real in-app toasts */}
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium text-gray-900 dark:text-white">Alert Pop-ups</p>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Show in-app notifications when a PPE violation is detected
              </p>
            </div>
            <Switch checked={alerts} onCheckedChange={handleAlerts} />
          </div>

          <div className="border-t border-gray-200 dark:border-gray-700" />

          {/* Push notifications — static informational only */}
          <div className="flex items-center justify-between opacity-60">
            <div>
              <p className="font-medium text-gray-900 dark:text-white">Push Notifications</p>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Device-level push notifications (managed by mobile phone)
              </p>
            </div>
            <Switch checked={false} disabled />
          </div>

          <div className="border-t border-gray-200 dark:border-gray-700" />

          {/* Sound alerts — controls audio on violation toast */}
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium text-gray-900 dark:text-white">Sound Alerts</p>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Play a sound when a critical violation pop-up appears
              </p>
            </div>
            <Switch checked={sound} onCheckedChange={handleSound} />
          </div>
        </CardContent>
      </Card>

      {/* Display Settings */}
      <Card className="shadow-sm dark:bg-gray-800 dark:border-gray-700">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-gray-900 dark:text-white">
            <Eye className="h-5 w-5 text-blue-600" /> Display
          </CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            Customize your visual experience
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium text-gray-900 dark:text-white">Dark Mode</p>
              <p className="text-sm text-gray-600 dark:text-gray-400">Enable dark theme across the portal</p>
            </div>
            <Switch checked={isDarkMode} onCheckedChange={toggleDarkMode} />
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default Settings;
