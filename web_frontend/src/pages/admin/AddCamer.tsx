import React, { useState, useEffect, useCallback } from 'react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Trash2, Plus, Edit2, Loader2 } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import {
  getAllCameras,
  createCamera,
  updateCamera as updateCameraFirebase,
  deleteCamera as deleteCameraFirebase,
} from '@/lib/firebaseCameras';
import api from '@/lib/api';

function AddCamer() {
  const [cameras, setCameras] = useState<FirebaseCamera[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [previewError, setPreviewError] = useState(false);
  const [formData, setFormData] = useState<{
    name: string;
    location: string;
    rtsp_url: string;
    site_id: string | null;
    enabled: boolean;
    fps_target: number;
  }>({
    name: '',
    location: '',
    rtsp_url: '',
    site_id: null,
    enabled: true,
    fps_target: 15,
  });
  const { toast } = useToast();

  const loadCameras = useCallback(async (showLoader = true) => {
    try {
      if (showLoader) setIsLoading(true);
      const data = await getAllCameras();
      setCameras(data);
    } catch (error) {
      console.error('Failed to load cameras:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to load cameras.',
      });
    } finally {
      if (showLoader) setIsLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    loadCameras();
  }, [loadCameras]);

  const extractHost = (urlString: string) => {
    if (!urlString) return '';
    try {
      const withProtocol = urlString.includes('://') ? urlString : `http://${urlString}`;
      const url = new URL(withProtocol);
      return url.hostname;
    } catch {
      return urlString;
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const newHost = extractHost(formData.rtsp_url);
    if (newHost) {
      const isDuplicate = cameras.some(cam => {
        if (editingId && cam.id === editingId) return false;
        return extractHost(cam.rtsp_url) === newHost;
      });

      if (isDuplicate) {
        toast({
          variant: 'destructive',
          title: 'Duplicate Camera',
          description: `A camera with the IP/Host ${newHost} is already registered.`,
        });
        return;
      }
    }

    setIsSubmitting(true);

    try {
      if (editingId) {
        await updateCameraFirebase(editingId, formData);
        await api.startCamera(editingId, formData.rtsp_url);
        toast({
          title: 'Success',
          description: 'Camera updated and worker restarted!',
        });
        setEditingId(null);
      } else {
        const newCam = await createCamera({
          ...formData,
          status: 'online',
        });
        await api.startCamera(newCam.id!, formData.rtsp_url);
        toast({
          title: 'Success',
          description: 'Camera created and worker started!',
        });
      }
      resetForm();
      loadCameras(false);
    } catch (error) {
      console.error('Failed to save camera:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to save camera.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      location: '',
      rtsp_url: '',
      site_id: null,
      enabled: true,
      fps_target: 15,
    });
    setShowForm(false);
    setEditingId(null);
    setPreviewUrl(null);
    setPreviewError(false);
  };

  const handleEdit = (camera: FirebaseCamera) => {
    setFormData({
      name: camera.name,
      location: camera.location,
      rtsp_url: camera.rtsp_url,
      site_id: camera.site_id,
      enabled: camera.enabled,
      fps_target: camera.fps_target,
    });
    setEditingId(camera.id!);
    setShowForm(true);
    setPreviewUrl(camera.rtsp_url);
    setPreviewError(false);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this camera?')) return;

    setDeletingId(id);
    try {
      await deleteCameraFirebase(id);
      toast({
        title: 'Success',
        description: 'Camera deleted successfully!',
      });
      loadCameras(false);
    } catch (error) {
      console.error('Failed to delete camera:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to delete camera.',
      });
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <div className="p-6 space-y-6 bg-white dark:bg-gray-900 min-h-screen">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Manage Cameras</h1>
        {!showForm && (
          <Button onClick={() => setShowForm(true)} className="gap-2">
            <Plus className="h-4 w-4" />
            Add New Camera
          </Button>
        )}
      </div>

      {showForm && (
        <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">{editingId ? 'Edit Camera' : 'Add New Camera'}</CardTitle>
            <CardDescription className="text-gray-600 dark:text-gray-400">
              {editingId ? 'Update camera details' : 'Create a new camera entry'}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="name" className="text-gray-900 dark:text-white">Camera Name</Label>
                  <Input
                    id="name"
                    placeholder="e.g., Front Entrance Camera"
                    value={formData.name}
                    onChange={(e) =>
                      setFormData({ ...formData, name: e.target.value })
                    }
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="location" className="text-gray-900 dark:text-white">Location</Label>
                  <Input
                    id="location"
                    placeholder="e.g., Main Gate"
                    value={formData.location}
                    onChange={(e) =>
                      setFormData({ ...formData, location: e.target.value })
                    }
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required
                  />
                </div>

                <div className="space-y-2 md:col-span-2">
                  <Label htmlFor="rtsp_url" className="text-gray-900 dark:text-white">Stream URL (RTSP or HTTP)</Label>
                  <div className="flex gap-2">
                    <Input
                      id="rtsp_url"
                      placeholder="e.g., http://192.168.100.23:4000/video"
                      value={formData.rtsp_url}
                      onChange={(e) => {
                        setFormData({ ...formData, rtsp_url: e.target.value });
                        setPreviewUrl(null);
                      }}
                      className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white flex-1"
                      required
                    />
                    <Button 
                      type="button" 
                      variant="secondary" 
                      onClick={() => {
                        setPreviewError(false);
                        // Auto-correct common IP Webcam mistake
                        let url = formData.rtsp_url.trim();
                        if (url.match(/^http:\/\/\d+\.\d+\.\d+\.\d+:4000\/?$/)) {
                          url = url.endsWith('/') ? url + 'video' : url + '/video';
                          setFormData({ ...formData, rtsp_url: url });
                          toast({ title: 'URL Auto-corrected', description: 'Added /video to the IP Webcam URL' });
                        }
                        setPreviewUrl(url);
                      }}
                    >
                      Test Preview
                    </Button>
                  </div>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    For the <b>IP Webcam</b> app, you must include <code className="bg-gray-100 dark:bg-gray-800 px-1 rounded">/video</code> at the end (e.g. <code>http://192.168.x.x:4000/video</code>).
                  </p>

                  {/* Preview Area */}
                  {previewUrl && (
                    <div className="mt-4 rounded-lg overflow-hidden border bg-black flex items-center justify-center relative" style={{ minHeight: '300px' }}>
                      {!previewError ? (
                        <img 
                          src={previewUrl} 
                          alt="Live Preview" 
                          className="w-full h-auto object-contain"
                          onError={() => setPreviewError(true)}
                        />
                      ) : (
                        <div className="text-center p-6 text-gray-400">
                          <AlertTriangle className="h-10 w-10 mx-auto text-yellow-500 mb-2" />
                          <p className="font-semibold text-white">Cannot load stream preview</p>
                          <p className="text-sm mt-2 max-w-sm">
                            Make sure you are on the same Wi-Fi network and that you added <b>/video</b> to the end of the URL.
                          </p>
                        </div>
                      )}
                      <div className="absolute top-2 left-2 bg-red-600 text-white text-xs px-2 py-1 rounded-full font-bold">PREVIEW</div>
                    </div>
                  )}
                </div>

                <div className="space-y-2">
                  <Label htmlFor="enabled" className="text-gray-900 dark:text-white">Status</Label>
                  <Select
                    value={formData.enabled ? 'true' : 'false'}
                    onValueChange={(value) =>
                      setFormData({
                        ...formData,
                        enabled: value === 'true',
                      })
                    }
                  >
                    <SelectTrigger className="bg-white border-gray-300 text-gray-900 dark:bg-gray-700 dark:border-gray-600 dark:text-white">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="true">Enabled</SelectItem>
                      <SelectItem value="false">Disabled</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="flex gap-2">
                <Button type="submit" className="w-full md:w-auto" disabled={isSubmitting}>
                  {isSubmitting ? (
                    <>
                      <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                      {editingId ? 'Updating...' : 'Creating...'}
                    </>
                  ) : (
                    editingId ? 'Update Camera' : 'Add Camera'
                  )}
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  onClick={resetForm}
                  className="w-full md:w-auto"
                >
                  Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      <div className="space-y-4">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-white">All Cameras ({cameras.length})</h2>

        {isLoading ? (
          <div className="flex justify-center items-center py-8">
            <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
          </div>
        ) : cameras.length === 0 ? (
          <Card className="bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
            <CardContent className="py-8 text-center text-gray-600 dark:text-gray-400">
              No cameras added yet. Create your first camera to get started.
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {cameras.map((camera) => (
              <Card key={camera.id} className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
                <CardHeader className="pb-3">
                  <div className="flex justify-between items-start">
                    <div>
                      <CardTitle className="text-lg text-gray-900 dark:text-white">{camera.name}</CardTitle>
                      <CardDescription className="text-xs mt-1 text-gray-500 dark:text-gray-400">
                        {camera.location}
                      </CardDescription>
                    </div>
                    <span
                      className={`text-xs px-2 py-1 rounded ${
                        camera.enabled
                          ? 'bg-green-100 text-green-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {camera.enabled ? 'Enabled' : 'Disabled'}
                    </span>
                  </div>
                </CardHeader>
                <CardContent className="space-y-2 text-sm">
                  <p className="text-gray-700 dark:text-gray-300 truncate">
                    <span className="text-gray-500">Stream:</span> {camera.rtsp_url.substring(0, 30)}...
                  </p>
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Status:</span>{' '}
                    <span className={
                      camera.status === 'online' ? 'text-green-600' :
                      camera.status === 'error' ? 'text-red-600' : 'text-yellow-600'
                    }>
                      {camera.status}
                    </span>
                  </p>
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Site:</span>{' '}
                    {camera.site_id ? 'Assigned' : 'Not assigned'}
                  </p>
                  <div className="flex gap-2 mt-4">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleEdit(camera)}
                      className="flex-1 gap-1"
                    >
                      <Edit2 className="h-3 w-3" />
                      Edit
                    </Button>
                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={() => handleDelete(camera.id!)}
                      disabled={deletingId === camera.id}
                      className="flex-1 gap-1"
                    >
                      {deletingId === camera.id ? (
                        <Loader2 className="h-3 w-3 animate-spin" />
                      ) : (
                        <Trash2 className="h-3 w-3" />
                      )}
                      Delete
                    </Button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default AddCamer;
