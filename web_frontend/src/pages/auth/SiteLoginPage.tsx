import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { useToast } from '@/hooks/use-toast';
import { getOfficerByLogin } from '@/lib/firebaseOfficers';
import { getSiteOfficerSession, setSiteOfficerSession } from '@/lib/authSession';

const LoginPage = () => {
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const { toast } = useToast();

  useEffect(() => {
    const siteData = getSiteOfficerSession();
    if (siteData) {
      navigate('/site');
    }
  }, [navigate]);

  const handleLogin = async (event: React.FormEvent) => {
    event.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      if (!identifier.trim() || !password.trim()) {
        setError('Please enter both login ID/email and password');
        return;
      }

      const officer = await getOfficerByLogin(identifier);
      if (!officer || !officer.id) {
        setError('No account found with this credential. Contact your admin.');
        return;
      }
      const officerData = officer;

      // Check if officer is active
      if (officerData.status !== 'active') {
        setError('Your account has been deactivated. Contact your admin.');
        return;
      }

      // Check if officer has any assigned sites
      if (!officerData.siteIds || officerData.siteIds.length === 0) {
        setError('You are not assigned to any site. Contact your admin.');
        return;
      }

      // Verify password
      if (officerData.password !== password) {
        setError('Invalid login credentials');
        return;
      }

      // Store officer data in localStorage
      const sessionData = {
        id: officer.id,
        loginId: officerData.loginId,
        name: officerData.name,
        email: officerData.email,
        phone: officerData.phone,
        siteIds: officerData.siteIds,
        status: officerData.status,
      };
      setSiteOfficerSession(sessionData);

      toast({
        title: 'Signed in successfully',
        description: `Welcome, ${officerData.name}!`,
      });
      navigate('/site');
    } catch (err: unknown) {
      console.error('Login error:', err);
      setError('An error occurred during sign in. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen bg-gray-50 dark:bg-slate-900">
      {/* Left side with image */}
      <div className="hidden lg:block lg:w-1/2 relative">
        <img
          src="https://images.unsplash.com/photo-1488590528505-98d2b5aba04b"
          alt="Smart Safety Technology"
          className="absolute inset-0 h-full w-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 to-black/30 flex items-center justify-center">
          <div className="max-w-lg p-8 text-white text-center">
            <h2 className="text-3xl font-bold mb-2">Safety Supervisor Portal</h2>
            <p className="text-lg opacity-90">Monitor your site with AI-powered safety detection.</p>
          </div>
        </div>
      </div>

      {/* Right side with login form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8">
        <div className="w-full max-w-md">
          <div className="text-center mb-6">
            <Link to="/" className="inline-block mb-4">
              <span className="text-primary-600 dark:text-primary-400 text-3xl font-bold">Smartcamera</span>
            </Link>
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Supervisor Sign In</h1>
            <p className="text-gray-600 dark:text-gray-300">
              Enter the credentials provided by your admin
            </p>
          </div>

          <div className="bg-white dark:bg-slate-800 rounded-lg shadow ring-1 ring-slate-900/5 dark:ring-white/5 px-8 py-10">
            {error && (
              <div className="bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-700 text-red-700 dark:text-red-200 px-4 py-3 rounded-lg mb-6">
                {error}
              </div>
            )}

            <form onSubmit={handleLogin} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="identifier" className="text-sm dark:text-gray-200">Login ID or email</Label>
                <Input
                  id="identifier"
                  type="text"
                  placeholder="e.g., so-john-1290 or you@company.com"
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  required
                  className="w-full bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-slate-700 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-400"
                />
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label htmlFor="password" className="text-sm dark:text-gray-200">Password</Label>
                </div>
                <Input
                  id="password"
                  type="password"
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-slate-700 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-400"
                />
              </div>

              <div className="flex items-center space-x-2">
                <Checkbox id="remember" defaultChecked />
                <Label htmlFor="remember" className="text-sm dark:text-gray-300">
                  Remember me for 30 days
                </Label>
              </div>

              <Button
                type="submit"
                className={`w-full ${isLoading ? 'opacity-80' : ''} bg-primary-600 hover:bg-primary-700 dark:bg-primary-500`}
                disabled={isLoading}
              >
                {isLoading ? 'Signing in...' : 'Sign in'}
              </Button>
            </form>

            <div className="mt-6 border-t border-gray-200 dark:border-slate-700 pt-4">
              <p className="text-center text-xs text-gray-600 dark:text-gray-300">
                Don't have credentials? Contact your site administrator.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
