import { useState, useEffect, useCallback, useRef, memo } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger
} from '@/components/ui/dropdown-menu';
import { useToast } from '@/hooks/use-toast';
import { useTheme } from '@/context/ThemeContext';
import { clearSiteOfficerSession, getSiteOfficerSession } from '@/lib/authSession';
import { getAllSites, type Site } from '@/lib/firebaseSites';
import {
  Home, Settings, LogOut, Menu, X, AlertCircle, CameraIcon,
  ChartAreaIcon, HistoryIcon, HelpCircle, SettingsIcon,
  UserCheck, UserCheck2, Paperclip, ChevronRight, Shield
} from 'lucide-react';

// ── Simple in-memory cache so site name doesn't re-fetch on every render ──
let _siteNameCache: { name: string; ts: number } | null = null;
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

const navigation = [
  { name: 'Dashboard', href: '/site', icon: Home },
  { name: 'Alerts', href: '/site/alerts', icon: AlertCircle },
  { name: 'History', href: '/site/history', icon: HistoryIcon },
  { name: 'Analytics', href: '/site/analytics', icon: ChartAreaIcon },
  { name: 'Cameras', href: '/site/allcameras', icon: CameraIcon },
];

const bottomNavigation = [
  { name: 'Profile', href: '/site/profile', icon: UserCheck },
  { name: 'Settings', href: '/site/setting', icon: SettingsIcon },
  { name: 'Help', href: '/site/help', icon: HelpCircle },
  { name: 'Terms & Conditions', href: '/site/termsConditions', icon: Paperclip },
];

// ── Initials avatar (no external image needed) ────────────────────────────
const InitialsAvatar = memo(({ name, size = 'sm' }: { name: string; size?: 'sm' | 'lg' }) => {
  const initials = name
    .split(' ')
    .map(n => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  const dim = size === 'lg' ? 'h-10 w-10 text-sm' : 'h-8 w-8 text-xs';
  return (
    <span
      className={`${dim} inline-flex items-center justify-center rounded-full font-bold text-white select-none`}
      style={{ background: 'linear-gradient(135deg,#6366f1 0%,#8b5cf6 50%,#06b6d4 100%)' }}
    >
      {initials || '?'}
    </span>
  );
});

// ── NavLink ────────────────────────────────────────────────────────────────
const NavLink = memo(({
  item, active, dark, onClick
}: {
  item: { name: string; href: string; icon: React.ElementType };
  active: boolean;
  dark: boolean;
  onClick?: () => void;
}) => {
  const Icon = item.icon;
  return (
    <Link
      to={item.href}
      onClick={onClick}
      className={`group flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-150
        ${active
          ? 'bg-gradient-to-r from-indigo-500/20 to-violet-500/10 text-indigo-600 dark:text-indigo-400'
          : dark
            ? 'text-gray-300 hover:bg-white/5 hover:text-white'
            : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
        }`}
    >
      <Icon
        className={`h-4.5 w-4.5 flex-shrink-0 ${active ? 'text-indigo-500' : 'text-gray-400 group-hover:text-gray-500'}`}
        aria-hidden
      />
      <span>{item.name}</span>
      {active && <ChevronRight className="ml-auto h-3.5 w-3.5 text-indigo-400" />}
    </Link>
  );
});

// ── Main Layout ────────────────────────────────────────────────────────────
const SiteLayout = () => {
  const [sidebarOpen, setSidebarOpen] = useState(false);         // mobile slide-in
  const [desktopOpen, setDesktopOpen] = useState(true);          // desktop collapse
  const [siteName, setSiteName] = useState('');
  const [userName, setUserName] = useState('Supervisor');
  const location = useLocation();
  const navigate = useNavigate();
  const { isDarkMode } = useTheme();
  const { toast } = useToast();
  const sidebarRef = useRef<HTMLDivElement>(null);

  // ── Auth guard + site name (cached) ──────────────────────────────────
  useEffect(() => {
    const session = getSiteOfficerSession();
    if (!session) { navigate('/site/login'); return; }
    setUserName(session.name || 'Supervisor');

    // Use cached site name if still fresh
    if (_siteNameCache && Date.now() - _siteNameCache.ts < CACHE_TTL) {
      setSiteName(_siteNameCache.name);
      return;
    }

    getAllSites().then(allSites => {
      const my = allSites.filter((s: Site) => session.siteIds?.includes(s.id || ''));
      const name = my.length === 1 ? my[0].name
        : my.length > 1 ? `${my.length} Sites`
          : 'No Site Assigned';
      _siteNameCache = { name, ts: Date.now() };
      setSiteName(name);
    }).catch(() => setSiteName('Assigned Sites'));
  }, []);

  // ── Close sidebar on route change ───────────────────────────────────
  useEffect(() => { setSidebarOpen(false); }, [location.pathname]);

  // ── Close sidebar on outside click ──────────────────────────────────
  useEffect(() => {
    const handle = (e: MouseEvent) => {
      if (sidebarOpen && sidebarRef.current && !sidebarRef.current.contains(e.target as Node)) {
        setSidebarOpen(false);
      }
    };
    document.addEventListener('mousedown', handle);
    return () => document.removeEventListener('mousedown', handle);
  }, [sidebarOpen]);

  const handleLogout = useCallback(() => {
    clearSiteOfficerSession();
    toast({ title: 'Logged out', description: 'You have been successfully logged out.' });
    setTimeout(() => navigate('/'), 300);
  }, []);

  // ── Sidebar content (shared between desktop and mobile) ──────────────
  const SidebarContent = () => (
    <>
      {/* Logo + collapse toggle */}
      <div className="flex items-center justify-between px-4 py-4 border-b border-black/5 dark:border-white/10">
        <div className="flex items-center gap-2.5">
          <div className="h-8 w-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: 'linear-gradient(135deg,#6366f1,#8b5cf6)' }}>
            <Shield className="h-4 w-4 text-white" />
          </div>
          <span className="text-base font-bold text-gray-900 dark:text-white tracking-tight">SmartCamera</span>
        </div>
        {/* Desktop hide button */}
        <button
          onClick={() => setDesktopOpen(false)}
          className="hidden md:flex p-1 rounded-md text-gray-400 hover:text-gray-600 dark:hover:text-white hover:bg-black/5 dark:hover:bg-white/5 transition"
          title="Hide sidebar"
        >
          <ChevronRight className="h-4 w-4 rotate-180" />
        </button>
      </div>

      {/* Main nav */}
      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-0.5">
        <p className="px-3 mb-2 text-[10px] font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">Navigation</p>
        {navigation.map(item => (
          <NavLink
            key={item.href}
            item={item}
            active={
              item.href === '/site'
                ? location.pathname === '/site'
                : location.pathname.startsWith(item.href)
            }
            dark={isDarkMode}
          />
        ))}

      </nav>

      {/* Bottom nav */}
      <div className={`px-3 py-4 border-t border-black/5 dark:border-white/10 space-y-0.5`}>
        <p className="px-3 mb-2 text-[10px] font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">Account</p>
        {bottomNavigation.map(item => (
          <NavLink
            key={item.href}
            item={item}
            active={location.pathname === item.href}
            dark={isDarkMode}
          />
        ))}
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 transition-all duration-150"
        >
          <LogOut className="h-4 w-4 flex-shrink-0" />
          Log Out
        </button>
      </div>
    </>
  );

  return (
    <div className={`min-h-screen flex ${isDarkMode ? 'bg-gray-900' : 'bg-gray-50'}`}>

      {/* ── Desktop sidebar (fixed, collapsible) ───────────────────────── */}
      <aside className={`hidden md:flex flex-col fixed inset-y-0 z-20 border-r
        transition-all duration-300 ease-in-out overflow-hidden
        ${desktopOpen ? 'w-64' : 'w-0 border-none'}
        ${isDarkMode
          ? 'bg-gray-800 border-gray-700'
          : 'border-gray-200 bg-gradient-to-b from-white via-gray-50/60 to-indigo-50/40'
        }`}
        style={desktopOpen ? { boxShadow: 'inset -3px 0 0 rgba(99,102,241,0.35), inset -8px 0 10px rgba(139,92,246,0.1)' } : undefined}
      >
        <SidebarContent />
      </aside>

      {/* ── Mobile backdrop ─────────────────────────────────────────────── */}
      <div
        className={`md:hidden fixed inset-0 z-30 bg-black/50 backdrop-blur-sm transition-opacity duration-300
          ${sidebarOpen ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}`}
        onClick={() => setSidebarOpen(false)}
      />

      {/* ── Mobile slide-in sidebar ─────────────────────────────────────── */}
      <div
        ref={sidebarRef}
        className={`md:hidden fixed inset-y-0 left-0 z-40 w-72 flex flex-col border-r shadow-2xl
          transition-transform duration-300 ease-in-out
          ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}
          ${isDarkMode
            ? 'bg-gray-800 border-gray-700'
            : 'border-gray-200 bg-gradient-to-b from-white via-gray-50/60 to-indigo-50/40'
          }`}
        style={{ boxShadow: 'inset -3px 0 0 rgba(99,102,241,0.35), inset -8px 0 10px rgba(139,92,246,0.1), 4px 0 20px rgba(0,0,0,0.15)' }}
      >
        {/* Close button */}
        <button
          onClick={() => setSidebarOpen(false)}
          className="absolute top-4 right-4 p-1.5 rounded-lg text-gray-400 hover:text-gray-600 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-700 transition"
          aria-label="Close sidebar"
        >
          <X className="h-4 w-4" />
        </button>
        <SidebarContent />
        {/* Right-edge gradient accent */}
        <div className="pointer-events-none absolute inset-y-0 right-0 w-[3px] bg-gradient-to-b from-indigo-500/40 via-violet-500/50 to-cyan-400/30" />
      </div>

      {/* ── Main content area ───────────────────────────────────────────── */}
      <div className={`flex-1 min-w-0 transition-all duration-300 ease-in-out ${desktopOpen ? 'md:ml-64' : 'md:ml-0'}`}>

        {/* Top header */}
        <header className={`sticky top-0 z-10 border-b flex items-center justify-between px-4 py-3 sm:px-6
          ${isDarkMode
            ? 'bg-gray-800/95 border-gray-700 backdrop-blur-sm'
            : 'bg-white/95 border-gray-200 backdrop-blur-sm shadow-sm'}`}
        >
          {/* Left: hamburger + site name */}
          <div className="flex items-center gap-3">
            {/* Mobile hamburger */}
            <button
              onClick={() => setSidebarOpen(true)}
              className={`md:hidden p-1.5 rounded-lg transition ${isDarkMode ? 'text-gray-300 hover:bg-gray-700' : 'text-gray-500 hover:bg-gray-100'}`}
              aria-label="Open sidebar"
            >
              <Menu className="h-5 w-5" />
            </button>

            {/* Desktop expand button — only shown when sidebar is hidden */}
            {!desktopOpen && (
              <button
                onClick={() => setDesktopOpen(true)}
                className={`hidden md:flex p-1.5 rounded-lg transition ${isDarkMode ? 'text-gray-300 hover:bg-gray-700' : 'text-gray-500 hover:bg-gray-100'}`}
                title="Show sidebar"
              >
                <Menu className="h-5 w-5" />
              </button>
            )}

            {/* Highlighted site name pill */}
            {siteName && (
              <div className="flex items-center gap-2">
                <span
                  className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-sm font-semibold"
                  style={{
                    background: isDarkMode
                      ? 'linear-gradient(90deg,rgba(99,102,241,.25),rgba(139,92,246,.15))'
                      : 'linear-gradient(90deg,rgba(99,102,241,.12),rgba(139,92,246,.08))',
                    color: isDarkMode ? '#a5b4fc' : '#4f46e5',
                    border: isDarkMode ? '1px solid rgba(99,102,241,.3)' : '1px solid rgba(99,102,241,.2)',
                  }}
                >
                  <Shield className="h-3.5 w-3.5" />
                  {siteName}
                </span>
                {/* Mobile: just the name text */}
                <span className="sm:hidden text-sm font-semibold text-indigo-600 dark:text-indigo-400">{siteName}</span>
              </div>
            )}
          </div>

          {/* Right: avatar dropdown */}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button className="flex items-center gap-2.5 rounded-full pr-1 pl-1 py-1 hover:bg-gray-100 dark:hover:bg-gray-700 transition outline-none ring-0" aria-label="User menu">
                <InitialsAvatar name={userName} />
                <span className="hidden sm:block text-sm font-medium text-gray-700 dark:text-gray-200 max-w-[120px] truncate">{userName}</span>
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-52">
              <DropdownMenuLabel className="font-normal">
                <div className="flex items-center gap-2.5 py-1">
                  <InitialsAvatar name={userName} size="lg" />
                  <div className="min-w-0">
                    <p className="text-sm font-semibold truncate">{userName}</p>
                    <p className="text-xs text-gray-500 truncate">Safety Officer</p>
                  </div>
                </div>
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={() => navigate('/site/profile')}>
                <UserCheck className="mr-2 h-4 w-4" /> Profile
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => navigate('/site/setting')}>
                <Settings className="mr-2 h-4 w-4" /> Settings
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={handleLogout} className="text-rose-600 focus:text-rose-600">
                <LogOut className="mr-2 h-4 w-4" /> Log out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>

        {/* Page content */}
        <main className="p-4 sm:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default SiteLayout;
