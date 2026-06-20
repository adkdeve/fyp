import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useToast } from '@/hooks/use-toast';
import { ArrowLeftCircle } from 'lucide-react';
import { db } from '@/lib/firebase';
import { doc, getDoc } from 'firebase/firestore';
const AdminLoginPage = () => {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    admin_email: '',
    password: '',
  });
  const { toast } = useToast();
  const navigate = useNavigate();

  // Check for existing token on mount
  useEffect(() => {
    const token = localStorage.getItem('admin');
    if (token) {
      navigate('/admin', { replace: true });
    }
  }, [navigate]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      // Fetch admin credentials from Firestore
      const adminDocRef = doc(db, 'admin', 'main');
      const adminDocSnap = await getDoc(adminDocRef);

      if (adminDocSnap.exists()) {
        const adminData = adminDocSnap.data();
        const storedEmail = adminData.email;
        const storedPassword = adminData.password;

        if (formData.admin_email === storedEmail && formData.password === storedPassword) {
          // Store admin token
          localStorage.setItem('admin', 'dummy-admin');
          
          toast({
            title: "Login successful",
            description: "Welcome back to the admin dashboard.",
          });
          navigate('/admin');
        } else {
          toast({
            variant: "destructive",
            title: "Login failed",
            description: "Invalid email or password. Please try again.",
          });
        }
      } else {
        toast({
          variant: "destructive",
          title: "Login failed",
          description: "Admin credentials not found. Please try again.",
        });
      }
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Login failed",
        description: "An error occurred during login. Please try again.",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <Card className="w-full max-w-md">
        <button onClick={() => navigate('/')} className="p-2">
          <ArrowLeftCircle />
        </button>
        <CardHeader className="space-y-1 text-center">
          
          <CardTitle className="text-2xl font-bold">Admin Login</CardTitle>
          <CardDescription>
            Enter your credentials to access the admin dashboard
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="admin_email">Email</Label>
              <Input
                id="admin_email"
                name="admin_email"
                placeholder="admin@smartcamera.com"
                type="email"
                value={formData.admin_email}
                onChange={handleChange}
                required
              />
            </div>
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label htmlFor="password">Password</Label>
                <a 
                  className="text-sm text-primary-600 hover:underline"
                  href="/admin/forgot-password"
                >
                  Forgot password?
                </a>
              </div>
              <Input
                id="password"
                name="password"
                type="password"
                placeholder="••••••••"
                value={formData.password}
                onChange={handleChange}
                required
              />
            </div>
          </form>
        </CardContent>
        <CardFooter className="flex flex-col">
          <Button 
            className="w-full" 
            onClick={handleSubmit}
            disabled={isSubmitting}
          >
            {isSubmitting ? "Signing in..." : "Sign In"}
          </Button>
          <p className="mt-4 text-xs text-center text-gray-500">
            Admin access is restricted to authorized personnel only.<br />
            For assistance, contact the system administrator.
          </p>
        </CardFooter>
      </Card>
    </div>
  );
};

export default AdminLoginPage;