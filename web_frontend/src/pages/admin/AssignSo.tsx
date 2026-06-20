import React, { useState, useEffect, useCallback } from 'react';
import { getAllSites, assignOfficerToSite, unassignOfficerFromSite, type Site as FirebaseSite } from '@/lib/firebaseSites';
import {
  getAllOfficers,
  assignOfficerToSite as assignOfficerToSiteFirebase,
  unassignOfficerFromSite as unassignOfficerFromSiteFirebase,
  type Officer as FirebaseOfficer,
} from '@/lib/firebaseOfficers';
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

function AssignSo() {
  const [officers, setOfficers] = useState<FirebaseOfficer[]>([]);
  const [isLoadingOfficers, setIsLoadingOfficers] = useState(true);
  const [sites, setSites] = useState<FirebaseSite[]>([]);
  const [isLoadingSites, setIsLoadingSites] = useState(true);
  const [selectedOfficerId, setSelectedOfficerId] = useState<string>('');
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

  const loadOfficers = useCallback(async (showLoader = true) => {
    try {
      if (showLoader) setIsLoadingOfficers(true);
      const data = await getAllOfficers();
      setOfficers(data);
    } catch (error) {
      console.error('Failed to load officers:', error);
    } finally {
      if (showLoader) setIsLoadingOfficers(false);
    }
  }, []);

  useEffect(() => {
    loadSites();
    loadOfficers();
  }, [loadSites, loadOfficers]);

  const handleAssign = async () => {
    if (!selectedOfficerId || selectedSiteIds.length === 0) {
      setMessage({ type: 'error', text: 'Please select officer and at least one site' });
      return;
    }

    const officer = officers.find(o => o.id === selectedOfficerId);
    if (!officer) {
      setMessage({ type: 'error', text: 'Officer not found' });
      return;
    }

    // Filter out sites the officer is already assigned to
    const newSiteIds = selectedSiteIds.filter(siteId => !officer.siteIds?.includes(siteId));

    if (newSiteIds.length === 0) {
      setMessage({ type: 'error', text: 'Officer is already assigned to all selected sites' });
      return;
    }

    setIsSubmitting(true);
    try {
      for (const siteId of newSiteIds) {
        // Keep both officer and site mappings in sync.
        await assignOfficerToSite(selectedOfficerId, siteId);
        await assignOfficerToSiteFirebase(selectedOfficerId, siteId);
      }
      setMessage({ type: 'success', text: `Officer assigned to ${newSiteIds.length} new site(s) successfully!` });
      setSelectedOfficerId('');
      setSelectedSiteIds([]);
      loadOfficers(false); // Reload officers to show updated site assignments
      loadSites(false); // Reload sites to show updated officer counts
      setTimeout(() => setMessage(null), 3000);
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to assign officer' });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleUnassign = async (officerId: string, siteId: string) => {
    setUnassigningId(`${officerId}-${siteId}`);
    try {
      // Keep both officer and site mappings in sync.
      await unassignOfficerFromSite(officerId, siteId);
      await unassignOfficerFromSiteFirebase(officerId, siteId);
      setMessage({ type: 'success', text: 'Officer unassigned from site successfully!' });
      loadOfficers(false); // Reload officers to show updated site assignments
      loadSites(false); // Reload sites to show updated officer counts
      setTimeout(() => setMessage(null), 3000);
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to unassign officer' });
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

  const getOfficerSites = (officerId: string) => {
    const officer = officers.find(o => o.id === officerId);
    return sites.filter(site => officer?.siteIds?.includes(site.id || '') || false);
  };

  return (
    <div className="p-6 space-y-6 bg-white dark:bg-gray-900 min-h-screen">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Assign Safety Officers to Sites</h1>
        <p className="text-gray-600 dark:text-gray-400 mt-2">Manage safety officer assignments to different locations</p>
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
              <CardDescription className="text-gray-600 dark:text-gray-400">Link an officer to a site</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-900 dark:text-white">Select Safety Officer</label>
                {isLoadingOfficers ? (
                  <div className="flex justify-center items-center py-2">
                    <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
                  </div>
                ) : officers.length === 0 ? (
                  <p className="text-sm text-gray-500 dark:text-gray-400">No officers available. Create officers first.</p>
                ) : (
                  <Select value={selectedOfficerId} onValueChange={setSelectedOfficerId}>
                    <SelectTrigger className="bg-white border-gray-300 text-gray-900 dark:bg-gray-700 dark:border-gray-600 dark:text-white">
                      <SelectValue placeholder="Choose officer..." />
                    </SelectTrigger>
                    <SelectContent>
                      {officers.map((officer) => (
                        <SelectItem key={officer.id} value={officer.id}>
                          {officer.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-900 dark:text-white">Select Sites (Multiple)</label>
                <div className="bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-md p-3 space-y-2 max-h-48 overflow-y-auto">
                  {isLoadingSites ? (
                    <div className="flex justify-center items-center py-4">
                      <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
                    </div>
                  ) : sites.length === 0 ? (
                    <p className="text-sm text-gray-500 dark:text-gray-400 text-center py-2">No sites available. Create sites first.</p>
                  ) : (
                    sites.map((site) => {
                      const officer = officers.find(o => o.id === selectedOfficerId);
                      const isAlreadyAssigned = officer?.siteIds?.includes(site.id || '');
                      return (
                        <div key={site.id} className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            id={site.id}
                            checked={isAlreadyAssigned || selectedSiteIds.includes(site.id)}
                            disabled={!!isAlreadyAssigned}
                            onChange={() => !isAlreadyAssigned && toggleSiteSelection(site.id)}
                            className={`w-4 h-4 rounded border-gray-300 bg-white dark:bg-gray-600 text-blue-500 ${isAlreadyAssigned ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
                          />
                          <label htmlFor={site.id} className={`text-sm flex-1 ${isAlreadyAssigned ? 'text-gray-400 dark:text-gray-500 cursor-not-allowed' : 'text-gray-900 dark:text-white cursor-pointer'}`}>
                            {site.name}
                          </label>
                          {isAlreadyAssigned && (
                            <span className="text-xs bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200 px-2 py-0.5 rounded">Assigned</span>
                          )}
                        </div>
                      );
                    })
                  )}
                </div>
                {selectedSiteIds.length > 0 && (
                  <p className="text-xs text-blue-400">{selectedSiteIds.length} new site(s) selected</p>
                )}
              </div>

              <Button onClick={handleAssign} className="w-full" size="lg" disabled={selectedSiteIds.length === 0 || isSubmitting}>
                {isSubmitting ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <CheckCircle className="h-4 w-4 mr-2" />}
                {selectedSiteIds.length > 0 ? `Assign to ${selectedSiteIds.length} New Site(s)` : 'Select New Sites to Assign'}
              </Button>
            </CardContent>
          </Card>
        </div>

        {/* Assigned Officers */}
        <div className="lg:col-span-2">
          <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
            <CardHeader>
              <CardTitle className="text-gray-900 dark:text-white">Officer Site Assignments</CardTitle>
              <CardDescription className="text-gray-600 dark:text-gray-400">View which officers are assigned to which sites</CardDescription>
            </CardHeader>
            <CardContent>
              {isLoadingOfficers ? (
                <div className="flex justify-center items-center py-8">
                  <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
                </div>
              ) : officers.length === 0 ? (
                <p className="text-center text-gray-600 dark:text-gray-400 py-8">No officers available</p>
              ) : (
                <div className="space-y-4">
                  {officers.map((officer) => {
                    const assignedSites = getOfficerSites(officer.id);
                    return (
                      <div
                        key={officer.id}
                        className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-white dark:bg-gray-800"
                      >
                        <div className="flex justify-between items-start mb-3">
                          <div className="flex-1">
                            <h3 className="font-semibold text-gray-900 dark:text-white">{officer.name}</h3>
                            <p className="text-sm text-gray-600 dark:text-gray-400">{officer.email}</p>
                            <p className="text-sm text-gray-600 dark:text-gray-400">{officer.phone}</p>
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
                                  onClick={() => handleUnassign(officer.id!, site.id!)}
                                  variant="ghost"
                                  size="sm"
                                  disabled={unassigningId === `${officer.id}-${site.id}`}
                                  className="h-6 px-2 text-xs text-red-400 hover:text-red-300 hover:bg-red-900/20 gap-1"
                                >
                                  {unassigningId === `${officer.id}-${site.id}` ? <Loader2 className="h-3 w-3 animate-spin" /> : null}
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

      {/* Unassigned Officers */}
      {!isLoadingOfficers && officers.filter(off => getOfficerSites(off.id).length === 0).length > 0 && (
        <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">Unassigned Officers ({officers.filter(off => getOfficerSites(off.id).length === 0).length})</CardTitle>
            <CardDescription className="text-gray-600 dark:text-gray-400">Officers not yet assigned to any site</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {officers.filter(off => getOfficerSites(off.id).length === 0).map((officer) => (
                <div
                  key={officer.id}
                  className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-yellow-50 dark:bg-yellow-900/10"
                >
                  <h3 className="font-semibold text-gray-900 dark:text-white">{officer.name}</h3>
                  <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">{officer.email}</p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">{officer.phone}</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">Join Date: {officer.joinDate}</p>
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

export default AssignSo;
