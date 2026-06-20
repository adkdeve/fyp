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
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Trash2, Plus, Edit2, MapPin, Loader2 } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import {
  getAllSites,
  createSite,
  updateSite as updateSiteFirebase,
  deleteSite as deleteSiteFirebase,
  type Site as FirebaseSite,
} from '@/lib/firebaseSites';

function ManageSites() {
  const [sites, setSites] = useState<FirebaseSite[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [formData, setFormData] = useState<{
    name: string;
    location: string;
    status: 'active' | 'inactive';
  }>({
    name: '',
    location: '',
    status: 'active',
  });
  const { toast } = useToast();

  const loadSites = useCallback(async (showLoader = true) => {
    try {
      if (showLoader) setIsLoading(true);
      const data = await getAllSites();
      setSites(data);
    } catch (error) {
      console.error('Failed to load sites:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to load sites.',
      });
    } finally {
      if (showLoader) setIsLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    loadSites();
  }, [loadSites]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      if (editingId) {
        await updateSiteFirebase(editingId, formData);
        toast({
          title: 'Success',
          description: 'Site updated successfully!',
        });
        setEditingId(null);
      } else {
        await createSite({
          ...formData,
          cameraIds: [],
          officerIds: [],
        });
        toast({
          title: 'Success',
          description: 'Site created successfully!',
        });
      }
      resetForm();
      loadSites(false);
    } catch (error) {
      console.error('Failed to save site:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to save site.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      location: '',
      status: 'active',
    });
    setShowForm(false);
    setEditingId(null);
  };

  const handleEdit = (site: FirebaseSite) => {
    setFormData({
      name: site.name,
      location: site.location,
      status: site.status,
    });
    setEditingId(site.id!);
    setShowForm(true);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this site?')) return;

    setDeletingId(id);
    try {
      await deleteSiteFirebase(id);
      toast({
        title: 'Success',
        description: 'Site deleted successfully!',
      });
      loadSites(false);
    } catch (error) {
      console.error('Failed to delete site:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to delete site.',
      });
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <div className="p-6 space-y-6 bg-white dark:bg-gray-900 min-h-screen">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Manage Sites</h1>
          <p className="text-gray-600 dark:text-gray-400 mt-1">Create and manage monitoring locations</p>
        </div>
        {!showForm && (
          <Button onClick={() => setShowForm(true)} className="gap-2">
            <Plus className="h-4 w-4" />
            Add New Site
          </Button>
        )}
      </div>

      {showForm && (
        <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">{editingId ? 'Edit Site' : 'Add New Site'}</CardTitle>
            <CardDescription className="text-gray-600 dark:text-gray-400">
              {editingId ? 'Update site details' : 'Create a new monitoring site location'}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2 md:col-span-2">
                  <Label htmlFor="name" className="text-gray-900 dark:text-white">Site Name *</Label>
                  <Input
                    id="name"
                    placeholder="e.g., Main Warehouse, Building A"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required
                  />
                </div>

                <div className="space-y-2 md:col-span-2">
                  <Label htmlFor="location" className="text-gray-900 dark:text-white">Location/Address</Label>
                  <Textarea
                    id="location"
                    placeholder="Full address of the site"
                    value={formData.location}
                    onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    rows={2}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="status" className="text-gray-900 dark:text-white">Status</Label>
                  <Select
                    value={formData.status}
                    onValueChange={(value) =>
                      setFormData({
                        ...formData,
                        status: value as 'active' | 'inactive',
                      })
                    }
                  >
                    <SelectTrigger className="bg-white border-gray-300 text-gray-900 dark:bg-gray-700 dark:border-gray-600 dark:text-white">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="active">Active</SelectItem>
                      <SelectItem value="inactive">Inactive</SelectItem>
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
                    editingId ? 'Update Site' : 'Create Site'
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

      {/* Sites List */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
          All Sites ({sites.length})
        </h2>

        {isLoading ? (
          <div className="flex justify-center items-center py-8">
            <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
          </div>
        ) : sites.length === 0 ? (
          <Card className="bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
            <CardContent className="py-8 text-center text-gray-600 dark:text-gray-400">
              <MapPin className="h-12 w-12 mx-auto mb-4 text-gray-400" />
              <p>No sites created yet. Create your first site to get started.</p>
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {sites.map((site) => (
              <Card key={site.id} className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
                <CardHeader className="pb-3">
                  <div className="flex justify-between items-start">
                    <div className="flex items-start gap-2">
                      <MapPin className="h-5 w-5 text-blue-500 mt-0.5" />
                      <div>
                        <CardTitle className="text-lg text-gray-900 dark:text-white">{site.name}</CardTitle>
                        {site.location && (
                          <CardDescription className="text-xs mt-1 text-gray-500 dark:text-gray-400">
                            {site.location}
                          </CardDescription>
                        )}
                      </div>
                    </div>
                    <span
                      className={`text-xs px-2 py-1 rounded ${
                        site.status === 'active'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {site.status}
                    </span>
                  </div>
                </CardHeader>
                <CardContent className="space-y-2 text-sm">
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Cameras:</span> {site.cameraIds.length}
                  </p>
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Officers:</span> {site.officerIds.length}
                  </p>
                  <div className="flex gap-2 mt-4">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleEdit(site)}
                      className="flex-1 gap-1"
                    >
                      <Edit2 className="h-3 w-3" />
                      Edit
                    </Button>
                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={() => handleDelete(site.id!)}
                      disabled={deletingId === site.id}
                      className="flex-1 gap-1"
                    >
                      {deletingId === site.id ? (
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

export default ManageSites;
