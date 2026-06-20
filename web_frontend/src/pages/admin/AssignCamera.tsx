import React, { useState, useEffect, useCallback } from 'react';
import {
  getAllSites,
  assignCameraToSite as assignCameraToSiteFirebase,
  unassignCameraFromSite as unassignCameraFromSiteFirebase,
  type Site as FirebaseSite,
} from '@/lib/firebaseSites';
import {
  getAllCameras,
  assignCameraToSite as assignCameraToSiteFirebaseCamera,
  unassignCameraFromSite as unassignCameraFromSiteFirebaseCamera,
  type Camera as FirebaseCamera,
} from '@/lib/firebaseCameras';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { CheckCircle, AlertCircle, Unlink, Loader2 } from 'lucide-react';

function AssignCamera() {
  const [cameras, setCameras] = useState<FirebaseCamera[]>([]);
  const [isLoadingCameras, setIsLoadingCameras] = useState(true);
  const [sites, setSites] = useState<FirebaseSite[]>([]);
  const [isLoadingSites, setIsLoadingSites] = useState(true);
  const [selectedCameraId, setSelectedCameraId] = useState<string>('');
  const [selectedSiteIds, setSelectedSiteIds] = useState<string[]>([]);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [unassigningId, setUnassigningId] = useState<string | null>(null);

  const loadSites = useCallback(async (showLoader = true) => {
    try {
      if (showLoader) setIsLoadingSites(true);
      const data = await getAllSites();
      setSites(data);
    } catch (error) {
      console.error('Failed to load sites:', error);
    } finally {
      if (showLoader) setIsLoadingSites(false);
    }
  }, []);

  const loadCameras = useCallback(async (showLoader = true) => {
    try {
      if (showLoader) setIsLoadingCameras(true);
      const data = await getAllCameras();
      setCameras(data);
    } catch (error) {
      console.error('Failed to load cameras:', error);
    } finally {
      if (showLoader) setIsLoadingCameras(false);
    }
  }, []);

  useEffect(() => {
    loadSites();
    loadCameras();
  }, [loadSites, loadCameras]);

  useEffect(() => {
    // Clear any site selections when switching the selected camera
    setSelectedSiteIds([]);
  }, [selectedCameraId]);

  const handleAssign = async () => {
    if (!selectedCameraId || selectedSiteIds.length === 0) {
      setMessage({ type: 'error', text: 'Please select camera and at least one site' });
      return;
    }

    setIsSubmitting(true);
    try {
      for (const siteId of selectedSiteIds) {
        // Keep both camera and site mappings in sync.
        await assignCameraToSiteFirebase(selectedCameraId, siteId);
        await assignCameraToSiteFirebaseCamera(selectedCameraId, siteId);
      }
      setMessage({ type: 'success', text: `Camera assigned to ${selectedSiteIds.length} site(s) successfully!` });
      setSelectedCameraId('');
      setSelectedSiteIds([]);
      loadCameras(false); // Reload cameras to show updated site assignments
      loadSites(false); // Reload sites to show updated camera counts
      setTimeout(() => setMessage(null), 3000);
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to assign camera' });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleUnassign = async (cameraId: string, siteId: string) => {
    setUnassigningId(`${cameraId}-${siteId}`);
    try {
      // Keep both camera and site mappings in sync.
      await unassignCameraFromSiteFirebase(cameraId, siteId);
      await unassignCameraFromSiteFirebaseCamera(cameraId);
      setMessage({ type: 'success', text: 'Camera unassigned from site successfully!' });
      loadCameras(false); // Reload cameras to show updated site assignments
      loadSites(false); // Reload sites to show updated camera counts
      setTimeout(() => setMessage(null), 3000);
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to unassign camera' });
    } finally {
      setUnassigningId(null);
    }
  };

  const toggleSiteSelection = (siteId: string) => {
    setSelectedSiteIds(prev =>
      prev.includes(siteId)
        ? prev.filter(id => id !== siteId)
        : [...prev, siteId]
    );
  };

  const getCameraSites = (cameraId: string) => {
    const camera = cameras.find(c => c.id === cameraId);
    if (!camera || !camera.site_id) return [];
    return sites.filter(site => site.id === camera.site_id);
  };

  return (
    <div className="p-6 space-y-6 bg-white dark:bg-gray-900 min-h-screen">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Assign Cameras to Sites</h1>
        <p className="text-gray-600 dark:text-gray-400 mt-2">Manage camera assignments to different monitoring locations</p>
      </div>

      {message && (
        <Alert variant={message.type === 'success' ? 'default' : 'destructive'}>
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>{message.text}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Assignment Form */}
        <div className="lg:col-span-1">
          <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
            <CardHeader>
              <CardTitle className="text-gray-900 dark:text-white">New Assignment</CardTitle>
              <CardDescription className="text-gray-600 dark:text-gray-400">Link a camera to a site</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-900 dark:text-white">Select Camera</label>
                {isLoadingCameras ? (
                  <div className="flex justify-center items-center py-2">
                    <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
                  </div>
                ) : cameras.length === 0 ? (
                  <p className="text-sm text-gray-500 dark:text-gray-400">No cameras available. Create cameras first.</p>
                ) : (
                  <Select value={selectedCameraId} onValueChange={setSelectedCameraId}>
                    <SelectTrigger className="bg-white border-gray-300 text-gray-900 dark:bg-gray-700 dark:border-gray-600 dark:text-white">
                      <SelectValue placeholder="Choose camera..." />
                    </SelectTrigger>
                    <SelectContent>
                      {cameras.map((camera) => (
                        <SelectItem key={camera.id} value={camera.id}>
                          {camera.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-900 dark:text-white">Select Site</label>
                <div className="bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-md p-3 space-y-2 max-h-48 overflow-y-auto">
                  {isLoadingSites ? (
                    <div className="flex justify-center items-center py-4">
                      <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
                    </div>
                  ) : sites.length === 0 ? (
                    <p className="text-sm text-gray-500 dark:text-gray-400 text-center py-2">No sites available. Create sites first.</p>
                  ) : (
                    sites.map((site) => {
                      const isAssigned = selectedCameraId
                        ? cameras.find(c => c.id === selectedCameraId)?.site_id === site.id
                        : false;
                      return (
                        <div key={site.id} className="flex items-center gap-2">
                          <input
                            type="radio"
                            id={site.id}
                            name="site"
                            checked={isAssigned || selectedSiteIds.includes(site.id)}
                            onChange={() => setSelectedSiteIds([site.id])}
                            className="w-4 h-4 rounded border-gray-300 bg-white dark:bg-gray-600 text-blue-500 cursor-pointer"
                          />
                          <label htmlFor={site.id} className="text-sm text-gray-900 dark:text-white cursor-pointer flex-1">
                            {site.name}
                          </label>
                          {isAssigned && (
                            <span className="text-xs bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 px-2 py-0.5 rounded">Current</span>
                          )}
                        </div>
                      );
                    })
                  )}
                </div>
                {selectedSiteIds.length > 0 && (
                  <p className="text-xs text-blue-400">{selectedSiteIds.length} site(s) selected</p>
                )}
              </div>

              <Button onClick={handleAssign} className="w-full" size="lg" disabled={isSubmitting}>
                {isSubmitting ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <CheckCircle className="h-4 w-4 mr-2" />}
                {selectedCameraId && cameras.find(c => c.id === selectedCameraId)?.site_id ? 'Reassign to Selected Site' : 'Assign to Selected Site'}
              </Button>
            </CardContent>
          </Card>
        </div>

        {/* Assigned Cameras */}
        <div className="lg:col-span-2">
          <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
            <CardHeader>
              <CardTitle className="text-gray-900 dark:text-white">Camera Site Assignments</CardTitle>
              <CardDescription className="text-gray-600 dark:text-gray-400">View which cameras are assigned to which sites</CardDescription>
            </CardHeader>
            <CardContent>
              {isLoadingCameras ? (
                <div className="flex justify-center items-center py-8">
                  <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
                </div>
              ) : cameras.length === 0 ? (
                <p className="text-center text-gray-600 dark:text-gray-400 py-8">No cameras available</p>
              ) : (
                <div className="space-y-4">
                  {cameras.map((camera) => {
                    const assignedSites = getCameraSites(camera.id);
                    return (
                      <div
                        key={camera.id}
                        className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-white dark:bg-gray-800"
                      >
                        <div className="flex justify-between items-start mb-3">
                          <div className="flex-1">
                            <h3 className="font-semibold text-gray-900 dark:text-white">{camera.name}</h3>
                            <p className="text-sm text-gray-600 dark:text-gray-400">{camera.location}</p>
                            <p className="text-xs text-gray-500 dark:text-gray-400 truncate">Stream: {camera.rtsp_url.substring(0, 30)}...</p>
                          </div>
                          <span className="text-xs bg-blue-900 text-blue-200 px-2 py-1 rounded">
                            {assignedSites.length} site(s)
                          </span>
                        </div>

                        {assignedSites.length > 0 ? (
                          <div className="bg-white dark:bg-gray-700 rounded p-2 space-y-1 mb-3">
                            {assignedSites.map((site) => (
                              <div key={site.id} className="flex justify-between items-center text-sm">
                                <span className="text-gray-700 dark:text-gray-300">📍 {site.name}</span>
                                <Button
                                  onClick={() => handleUnassign(camera.id!, site.id!)}
                                  variant="ghost"
                                  size="sm"
                                  disabled={unassigningId === `${camera.id}-${site.id}`}
                                  className="h-6 px-2 text-xs text-red-400 hover:text-red-300 hover:bg-red-900/20 gap-1"
                                >
                                  {unassigningId === `${camera.id}-${site.id}` ? <Loader2 className="h-3 w-3 animate-spin" /> : null}
                                  Remove
                                </Button>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">No sites assigned</p>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Unassigned Cameras */}
      {!isLoadingCameras && cameras.filter(cam => getCameraSites(cam.id).length === 0).length > 0 && (
        <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">Unassigned Cameras ({cameras.filter(cam => getCameraSites(cam.id).length === 0).length})</CardTitle>
            <CardDescription className="text-gray-600 dark:text-gray-400">Cameras not yet assigned to any site</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {cameras.filter(cam => getCameraSites(cam.id).length === 0).map((camera) => (
                <div
                  key={camera.id}
                  className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-yellow-50 dark:bg-yellow-900/10"
                >
                  <h3 className="font-semibold text-gray-900 dark:text-white">{camera.name}</h3>
                  <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">{camera.location}</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-2 truncate">Stream: {camera.rtsp_url.substring(0, 30)}...</p>
                  <div className="mt-3 inline-block">
                    <span className="text-xs bg-yellow-900 text-yellow-200 px-2 py-1 rounded">
                      ⚠️ No Sites Assigned
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

export default AssignCamera;
