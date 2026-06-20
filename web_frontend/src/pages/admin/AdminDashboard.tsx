import React, { useState, useEffect, useCallback } from "react";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Loader2, Video, AlertTriangle } from "lucide-react";
import { getAllSites } from "@/lib/firebaseSites";
import { getAllCameras, type Camera } from "@/lib/firebaseCameras";
import { getAllOfficers } from "@/lib/firebaseOfficers";
import { subscribeToViolations, type ViolationRecord } from "@/lib/firebaseViolations";
import api from "@/lib/api";
import CameraStream from "@/components/CameraStream";


function CameraCard({ cam }: { cam: Camera }) {
  const [err, setErr] = React.useState(false);
  return (
    <div className="rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
      <div className="relative bg-black" style={{ minHeight: '200px' }}>
        {cam.enabled ? (
          <CameraStream
            cameraId={cam.id!}
            className="w-full h-48 object-cover"
            onError={(hasError) => setErr(hasError)}
            refreshInterval={100}
          />
        ) : null}
        {/* Dynamic LIVE / OFFLINE badge */}
        {cam.enabled && !err ? (
          <div className="absolute top-2 left-2 bg-red-600 text-white text-xs px-2 py-1 rounded-full font-bold flex items-center gap-1">
            <span className="h-1.5 w-1.5 rounded-full bg-white animate-pulse" />
            LIVE
          </div>
        ) : (
          <div className="absolute top-2 left-2 bg-gray-600 text-white text-xs px-2 py-1 rounded-full font-bold">
            OFFLINE
          </div>
        )}
        <div className={`absolute top-2 right-2 text-xs px-2 py-1 rounded-full font-medium ${cam.enabled ? 'bg-green-500 text-white' : 'bg-gray-500 text-white'}`}>
          {cam.enabled ? 'Online' : 'Offline'}
        </div>
      </div>
      <div className="p-3 bg-white dark:bg-gray-800">
        <h3 className="font-medium text-gray-900 dark:text-white">{cam.name}</h3>
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">{cam.location}</p>
        <p className="text-xs text-gray-400 dark:text-gray-500 mt-1 truncate font-mono">{cam.rtsp_url}</p>
      </div>
    </div>
  );
}

function AdminDashboard() {
  const [isLoading, setIsLoading] = useState(true);
  const [totalCameras, setTotalCameras] = useState(0);
  const [totalSites, setTotalSites] = useState(0);
  const [totalOfficers, setTotalOfficers] = useState(0);
  const [activeCameras, setActiveCameras] = useState(0);
  const [cameras, setCameras] = useState<Camera[]>([]);
  const [violations, setViolations] = useState<ViolationRecord[]>([]);
  const [backendStatus, setBackendStatus] = useState<string>('checking...');

  const loadData = useCallback(async () => {
    try {
      setIsLoading(true);
      const [sites, cams, officers] = await Promise.all([
        getAllSites(),
        getAllCameras(),
        getAllOfficers(),
      ]);
      setTotalSites(sites.length);
      setTotalCameras(cams.length);
      setTotalOfficers(officers.length);
      setActiveCameras(cams.filter(c => c.enabled).length);
      setCameras(cams);

      // Check backend health
      const health = await api.healthCheck();
      setBackendStatus(health.status === 'ok' ? 'Connected' : 'Offline');
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
      setBackendStatus('Offline');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Subscribe to violations
  useEffect(() => {
    const unsub = subscribeToViolations((v) => setViolations(v));
    return () => unsub();
  }, []);

  return (
    <div className="p-6 space-y-6 bg-white dark:bg-gray-900 min-h-screen">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Admin Analytics Dashboard</h1>
        <div className="flex gap-2">
          <Button variant="outline" asChild>
            <Link to="/admin/sites">Manage Sites</Link>
          </Button>
        </div>
      </div>

      {isLoading ? (
        <div className="flex justify-center items-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
        </div>
      ) : (
        <>
          {/* Stats Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
              <CardHeader>
                <CardTitle className="text-gray-900 dark:text-white">Total Sites</CardTitle>
                <CardDescription className="text-gray-600 dark:text-gray-400">Monitoring locations</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-4xl font-bold text-blue-500">{totalSites}</p>
              </CardContent>
            </Card>

            <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
              <CardHeader>
                <CardTitle className="text-gray-900 dark:text-white">Active Cameras</CardTitle>
                <CardDescription className="text-gray-600 dark:text-gray-400">Live monitoring sources</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-4xl font-bold text-emerald-500">{activeCameras}</p>
                <p className="text-sm text-gray-500 mt-1">of {totalCameras} total</p>
              </CardContent>
            </Card>

            <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
              <CardHeader>
                <CardTitle className="text-gray-900 dark:text-white">Total Officers</CardTitle>
                <CardDescription className="text-gray-600 dark:text-gray-400">Safety personnel</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-4xl font-bold text-green-500">{totalOfficers}</p>
              </CardContent>
            </Card>

            <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
              <CardHeader>
                <CardTitle className="text-gray-900 dark:text-white">Violations</CardTitle>
                <CardDescription className="text-gray-600 dark:text-gray-400">Recent detections</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-4xl font-bold text-orange-500">{violations.length}</p>
              </CardContent>
            </Card>
          </div>

          {/* Live Camera Feeds */}
          <Card className="shadow-xl bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
            <CardHeader>
              <CardTitle className="text-gray-900 dark:text-white flex items-center gap-2">
                <Video className="h-5 w-5 text-blue-600" />
                Live Camera Feeds
              </CardTitle>
              <CardDescription className="text-gray-600 dark:text-gray-400">
                All cameras streaming from your sites
              </CardDescription>
            </CardHeader>
            <CardContent>
              {cameras.length === 0 ? (
                <div className="text-center py-8 text-gray-500 dark:text-gray-400">
                  No cameras configured. <Link to="/admin/AddCamera" className="text-blue-500 underline">Add a camera</Link>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {cameras.map((cam) => (
                  <CameraCard key={cam.id} cam={cam} />
                ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Recent Violations + Quick Actions */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Quick Actions */}
            <Card className="shadow-xl col-span-2 bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
              <CardHeader>
                <CardTitle className="text-gray-900 dark:text-white">Quick Actions</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <Button asChild className="h-24 flex-col gap-2">
                    <Link to="/admin/sites"><span className="text-2xl">📍</span><span className="text-sm">Manage Sites</span></Link>
                  </Button>
                  <Button asChild variant="outline" className="h-24 flex-col gap-2">
                    <Link to="/admin/AddCamera"><span className="text-2xl">📷</span><span className="text-sm">Add Camera</span></Link>
                  </Button>
                  <Button asChild variant="outline" className="h-24 flex-col gap-2">
                    <Link to="/admin/AddSo"><span className="text-2xl">👷</span><span className="text-sm">Add Officer</span></Link>
                  </Button>
                  <Button asChild variant="outline" className="h-24 flex-col gap-2">
                    <Link to="/admin/AssignCamera"><span className="text-2xl">🔗</span><span className="text-sm">Assign Camera</span></Link>
                  </Button>
                </div>
              </CardContent>
            </Card>

            {/* System Status */}
            <Card className="shadow-xl bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
              <CardHeader>
                <CardTitle className="text-gray-900 dark:text-white">System Status</CardTitle>
                <CardDescription className="text-gray-600 dark:text-gray-400">Overall health</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600 dark:text-gray-400">Firebase Connection</span>
                    <span className="text-sm text-green-500 font-semibold">Connected</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600 dark:text-gray-400">AI Backend</span>
                    <span className={`text-sm font-semibold ${backendStatus === 'Connected' ? 'text-green-500' : 'text-red-500'}`}>
                      {backendStatus}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600 dark:text-gray-400">Recent Violations</span>
                    <span className="text-sm text-orange-500 font-semibold">{violations.length}</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Recent Violations List */}
          {violations.length > 0 && (
            <Card className="shadow-xl bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
              <CardHeader>
                <CardTitle className="text-gray-900 dark:text-white flex items-center gap-2">
                  <AlertTriangle className="h-5 w-5 text-red-500" />
                  Recent Violations
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {violations.slice(0, 10).map((v) => (
                    <div key={v.id} className={`p-3 rounded-lg border flex justify-between items-start ${
                      v.severity === 'high' ? 'border-red-200 bg-red-50 dark:border-red-800 dark:bg-red-900/20' :
                      v.severity === 'medium' ? 'border-amber-200 bg-amber-50 dark:border-amber-800 dark:bg-amber-900/20' :
                      'border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-700'
                    }`}>
                      <div>
                        <p className="font-medium text-gray-900 dark:text-white">
                          {v.type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}
                        </p>
                        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                          Camera: {v.camera_id?.slice(0, 8)}... • Confidence: {(v.confidence * 100).toFixed(0)}%
                        </p>
                      </div>
                      <span className={`text-xs px-2 py-1 rounded-full text-white ${
                        v.severity === 'high' ? 'bg-red-600' : v.severity === 'medium' ? 'bg-amber-500' : 'bg-gray-500'
                      }`}>{v.severity}</span>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}
        </>
      )}
    </div>
  );
}

export default AdminDashboard;
