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
  getAllOfficers,
  createOfficer,
  updateOfficer as updateOfficerFirebase,
  deleteOfficer as deleteOfficerFirebase,
  type Officer as FirebaseOfficer,
} from '@/lib/firebaseOfficers';

function AddSO() {
  const generateLoginId = (name: string) => {
    const slug = name.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    const suffix = Math.floor(1000 + Math.random() * 9000);
    return `so-${slug || 'user'}-${suffix}`;
  };

  const generatePassword = () => {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    let out = '';
    for (let i = 0; i < 8; i += 1) out += chars[Math.floor(Math.random() * chars.length)];
    return out;
  };

  const [officers, setOfficers] = useState<FirebaseOfficer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [formData, setFormData] = useState<{
    name: string;
    email: string;
    phone: string;
    loginId: string;
    password: string;
    status: 'active' | 'inactive';
  }>({
    name: '',
    email: '',
    phone: '',
    loginId: '',
    password: '',
    status: 'active',
  });
  const { toast } = useToast();

  const loadOfficers = useCallback(async (showLoader = true) => {
    try {
      if (showLoader) setIsLoading(true);
      const data = await getAllOfficers();
      setOfficers(data);
    } catch (error) {
      console.error('Failed to load officers:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to load officers.',
      });
    } finally {
      if (showLoader) setIsLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    loadOfficers();
  }, [loadOfficers]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      if (editingId) {
        await updateOfficerFirebase(editingId, formData);
        toast({
          title: 'Success',
          description: 'Officer updated successfully!',
        });
        setEditingId(null);
      } else {
        await createOfficer({
          ...formData,
          loginId: formData.loginId.trim().toLowerCase(),
          email: formData.email.trim().toLowerCase(),
          siteIds: [],
          joinDate: new Date().toISOString().split('T')[0],
        });
        toast({
          title: 'Success',
          description: 'Officer created successfully!',
        });
      }
      resetForm();
      loadOfficers(false);
    } catch (error) {
      console.error('Failed to save officer:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to save officer.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      email: '',
      phone: '',
      loginId: '',
      password: '',
      status: 'active',
    });
    setShowForm(false);
    setEditingId(null);
  };

  const handleEdit = (officer: FirebaseOfficer) => {
    setFormData({
      name: officer.name,
      email: officer.email,
      phone: officer.phone,
      loginId: officer.loginId || '',
      password: officer.password || '',
      status: officer.status,
    });
    setEditingId(officer.id!);
    setShowForm(true);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this officer?')) return;

    setDeletingId(id);
    try {
      await deleteOfficerFirebase(id);
      toast({
        title: 'Success',
        description: 'Officer deleted successfully!',
      });
      loadOfficers(false);
    } catch (error) {
      console.error('Failed to delete officer:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to delete officer.',
      });
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <div className="p-6 space-y-6 bg-white dark:bg-gray-900 min-h-screen">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Manage Safety Officers</h1>
        {!showForm && (
          <Button onClick={() => setShowForm(true)} className="gap-2">
            <Plus className="h-4 w-4" />
            Add New Officer
          </Button>
        )}
      </div>

      {showForm && (
        <Card className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
          <CardHeader>
            <CardTitle className="text-gray-900 dark:text-white">{editingId ? 'Edit Officer' : 'Add New Safety Officer'}</CardTitle>
            <CardDescription className="text-gray-600 dark:text-gray-400">
              {editingId ? 'Update officer details' : 'Create a new safety officer entry'}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="name" className="text-gray-900 dark:text-white">Full Name</Label>
                  <Input
                    id="name"
                    placeholder="e.g., John Smith"
                    value={formData.name}
                    onChange={(e) =>
                      setFormData({ ...formData, name: e.target.value })
                    }
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="email" className="text-gray-900 dark:text-white">Email Address</Label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="e.g., john@company.com"
                    value={formData.email}
                    onChange={(e) =>
                      setFormData({ ...formData, email: e.target.value })
                    }
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="phone" className="text-gray-900 dark:text-white">Phone Number</Label>
                  <Input
                    id="phone"
                    placeholder="e.g., +1-555-0101"
                    value={formData.phone}
                    onChange={(e) =>
                      setFormData({ ...formData, phone: e.target.value })
                    }
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="password" className="text-gray-900 dark:text-white">Login Password *</Label>
                  <Input
                    id="password"
                    type="text"
                    placeholder="Password for site portal login"
                    value={formData.password}
                    onChange={(e) =>
                      setFormData({ ...formData, password: e.target.value })
                    }
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required={!editingId}
                  />
                  <p className="text-xs text-gray-500 dark:text-gray-400">Officer uses this to login at /site/login</p>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="loginId" className="text-gray-900 dark:text-white">Easy Login ID *</Label>
                  <Input
                    id="loginId"
                    type="text"
                    placeholder="e.g., so-john-1290"
                    value={formData.loginId}
                    onChange={(e) =>
                      setFormData({ ...formData, loginId: e.target.value.toLowerCase() })
                    }
                    className="bg-white border-gray-300 text-gray-900 placeholder:text-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                    required
                  />
                  <div className="flex gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() =>
                        setFormData((prev) => ({
                          ...prev,
                          loginId: generateLoginId(prev.name),
                          password: prev.password || generatePassword(),
                        }))
                      }
                    >
                      Generate Easy Credentials
                    </Button>
                  </div>
                  <p className="text-xs text-gray-500 dark:text-gray-400">Supervisor can sign in using this ID and password.</p>
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
                    editingId ? 'Update Officer' : 'Add Officer'
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
        <h2 className="text-xl font-semibold text-gray-900 dark:text-white">All Safety Officers ({officers.length})</h2>

        {isLoading ? (
          <div className="flex justify-center items-center py-8">
            <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
          </div>
        ) : officers.length === 0 ? (
          <Card className="bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
            <CardContent className="py-8 text-center text-gray-600 dark:text-gray-400">
              No safety officers added yet. Create your first officer to get started.
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {officers.map((officer) => (
              <Card key={officer.id} className="shadow-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700">
                <CardHeader className="pb-3">
                  <div className="flex justify-between items-start">
                    <div>
                      <CardTitle className="text-lg text-gray-900 dark:text-white">{officer.name}</CardTitle>
                      <CardDescription className="text-xs mt-1 text-gray-500 dark:text-gray-400">
                        {officer.email}
                      </CardDescription>
                    </div>
                    <span
                      className={`text-xs px-2 py-1 rounded ${
                        officer.status === 'active'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {officer.status}
                    </span>
                  </div>
                </CardHeader>
                <CardContent className="space-y-2 text-sm">
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Phone:</span> {officer.phone}
                  </p>
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Login ID:</span>{' '}
                    <code className="bg-gray-100 dark:bg-gray-700 px-1 rounded text-xs">{officer.loginId || 'Not set'}</code>
                  </p>
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Password:</span>{' '}
                    <code className="bg-gray-100 dark:bg-gray-700 px-1 rounded text-xs">{officer.password || 'Not set'}</code>
                  </p>
                  <p className="text-gray-700 dark:text-gray-300">
                    <span className="text-gray-500">Assigned:</span>{' '}
                    {officer.siteIds && officer.siteIds.length > 0 ? `${officer.siteIds.length} site(s)` : 'Not assigned'}
                  </p>
                  <div className="flex gap-2 mt-4">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleEdit(officer)}
                      className="flex-1 gap-1"
                    >
                      <Edit2 className="h-3 w-3" />
                      Edit
                    </Button>
                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={() => handleDelete(officer.id!)}
                      disabled={deletingId === officer.id}
                      className="flex-1 gap-1"
                    >
                      {deletingId === officer.id ? (
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

export default AddSO;
