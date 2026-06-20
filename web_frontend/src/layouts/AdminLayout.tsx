import { useState, useEffect, useCallback, useRef, memo } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { useTheme } from '@/context/ThemeContext';
import { useToast } from '@/hooks/use-toast';
import {
  LayoutDashboard, MapPin, Camera, Video, UserPlus, Users,
  LogOut, Menu, X, ChevronRight, Shield, Settings, Sun, Moon,
} from 'lucide-react';

// ── Navigation items ────────────────────────────────────────────────────────
const navigation = [
  { name: 'Dashboard',             href: '/admin',              icon: LayoutDashboard },
  { name: ' Sites',          href: '/admin/sites',        icon: MapPin },
  { name: ' Cameras',            href: '/admin/AddCamera',    icon: Camera },
  { name: 'Assign Camera to Site', href: '/admin/AssignCamera', icon: Video },
  { name: ' Manage Safety Officer',    href: '/admin/AddSo',        icon: UserPlus },
  { name: 'Assign Officer to Site',href: '/admin/AssignSo',     icon: Users },
];

// ── Initials avatar (identical to SiteLayout) ───────────────────────────────
const InitialsAvatar = memo(({ name, size = 'sm' }: { name: string; size?: 'sm' | 'lg' }) => {
  const initials = name
    .split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
  const dim = size === 'lg' ? 'h-10 w-10 text-sm' : 'h-8 w-8 text-xs';
  return (
    <span
      className={`${dim} inline-flex items-center justify-center rounded-full font-bold text-white select-none`}
      style={{ background: 'linear-gradient(135deg,#6366f1 0%,#8b5cf6 50%,#06b6d4 100%)' }}
    >
      {initials || 'A'}
    </span>
  );
});

// ── NavLink (identical style to SiteLayout) ─────────────────────────────────
const NavLink = memo(({
  item, active, dark, onClick,
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
      <Icon className={`h-4 w-4 flex-shrink-0 ${active ? 'text-indigo-500' : 'text-gray-400 group-hover:text-gray-500'}`} aria-hidden />
      <span className="truncate">{item.name}</span>
      {active && <ChevronRight className="ml-auto h-3.5 w-3.5 text-indigo-400 flex-shrink-0" />}
    </Link>
  );
});

// ── Main Layout ─────────────────────────────────────────────────────────────
const AdminLayout = () => {
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false);
  const [desktopOpen, setDesktopOpen] = useState(true);
  const location = useLocation();
  const navigate = useNavigate();
  const { isDarkMode, toggleDarkMode } = useTheme();
  const { toast } = useToast();
  const sidebarRef = useRef<HTMLDivElement>(null);

  const ADMIN_NAME = 'Ahmed';

  // Close mobile sidebar on route change
  useEffect(() => { setMobileSidebarOpen(false); }, [location.pathname]);

  // Close mobile sidebar on outside click
  useEffect(() => {
    const handle = (e: MouseEvent) => {
      if (mobileSidebarOpen && sidebarRef.current && !sidebarRef.current.contains(e.target as Node)) {
        setMobileSidebarOpen(false);
      }
    };
    document.addEventListener('mousedown', handle);
    return () => document.removeEventListener('mousedown', handle);
  }, [mobileSidebarOpen]);

  const handleLogout = useCallback(() => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin');
    toast({ title: 'Logged out', description: 'You have been successfully logged out.' });
    setTimeout(() => navigate('/'), 300);
  }, []);

  // ── Sidebar content ────────────────────────────────────────────────────────
  const SidebarContent = () => (
    <>
      {/* Logo + collapse toggle */}
      <div className="flex items-center justify-between px-4 py-4 border-b border-black/5 dark:border-white/10">
        <div className="flex items-center gap-2.5">
          <div
            className="h-8 w-8 rounded-lg flex items-center justify-center flex-shrink-0"
            style={{ background: 'linear-gradient(135deg,#6366f1,#8b5cf6)' }}
          >
            <Shield className="h-4 w-4 text-white" />
          </div>
          <div>
            <span className="text-sm font-bold text-gray-900 dark:text-white tracking-tight leading-none block">SmartCamera</span>
            <span className="text-[10px] font-medium text-indigo-500 dark:text-indigo-400 tracking-wide">Admin Portal</span>
          </div>
        </div>
        {/* Desktop hide button */}
        <button
          onClick={() => setDesktopOpen(false)}
          className="hidden md:flex p-1 rounded-md text-gray-400 hover:text-gray-600 dark:hover:text-white hover:bg-black/5 dark:hover:bg-white/5 transition"
          title="Collapse sidebar"
        >
          <ChevronRight className="h-4 w-4 rotate-180" />
        </button>
      </div>

      {/* Main nav */}
      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-0.5">
        <p className="px-3 mb-2 text-[10px] font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">
          Management
        </p>
        {navigation.map(item => (
          <NavLink
            key={item.href}
            item={item}
            active={location.pathname === item.href || (item.href === '/admin' && location.pathname === '/admin')}
            dark={isDarkMode}
          />
        ))}
      </nav>

      {/* Bottom: logout */}
      <div className="px-3 py-4 border-t border-black/5 dark:border-white/10 space-y-0.5">
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

      {/* ── Desktop sidebar (fixed, collapsible) ─────────────────────────── */}
      <aside
        className={`hidden md:flex flex-col fixed inset-y-0 z-20 border-r
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

      {/* ── Mobile backdrop ───────────────────────────────────────────────── */}
      <div
        className={`md:hidden fixed inset-0 z-30 bg-black/50 backdrop-blur-sm transition-opacity duration-300
          ${mobileSidebarOpen ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}`}
        onClick={() => setMobileSidebarOpen(false)}
      />

      {/* ── Mobile slide-in drawer ────────────────────────────────────────── */}
      <div
        ref={sidebarRef}
        className={`md:hidden fixed inset-y-0 left-0 z-40 w-72 flex flex-col border-r shadow-2xl
          transition-transform duration-300 ease-in-out
          ${mobileSidebarOpen ? 'translate-x-0' : '-translate-x-full'}
          ${isDarkMode
            ? 'bg-gray-800 border-gray-700'
            : 'border-gray-200 bg-gradient-to-b from-white via-gray-50/60 to-indigo-50/40'
          }`}
        style={{ boxShadow: 'inset -3px 0 0 rgba(99,102,241,0.35), inset -8px 0 10px rgba(139,92,246,0.1), 4px 0 20px rgba(0,0,0,0.15)' }}
      >
        <button
          onClick={() => setMobileSidebarOpen(false)}
          className="absolute top-4 right-4 p-1.5 rounded-lg text-gray-400 hover:text-gray-600 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-700 transition"
          aria-label="Close sidebar"
        >
          <X className="h-4 w-4" />
        </button>
        <SidebarContent />
        {/* Right-edge gradient accent */}
        <div className="pointer-events-none absolute inset-y-0 right-0 w-[3px] bg-gradient-to-b from-indigo-500/40 via-violet-500/50 to-cyan-400/30" />
      </div>

      {/* ── Main content ─────────────────────────────────────────────────── */}
      <div className={`flex-1 min-w-0 transition-all duration-300 ease-in-out ${desktopOpen ? 'md:ml-64' : 'md:ml-0'}`}>

        {/* Sticky top header */}
        <header
          className={`sticky top-0 z-10 border-b flex items-center justify-between px-4 py-3 sm:px-6
            ${isDarkMode
              ? 'bg-gray-800/95 border-gray-700 backdrop-blur-sm'
              : 'bg-white/95 border-gray-200 backdrop-blur-sm shadow-sm'}`}
        >
          {/* Left: hamburger (mobile) / expand btn (desktop) + badge */}
          <div className="flex items-center gap-3">
            {/* Mobile hamburger */}
            <button
              onClick={() => setMobileSidebarOpen(true)}
              className={`md:hidden p-1.5 rounded-lg transition ${isDarkMode ? 'text-gray-300 hover:bg-gray-700' : 'text-gray-500 hover:bg-gray-100'}`}
              aria-label="Open sidebar"
            >
              <Menu className="h-5 w-5" />
            </button>

            {/* Desktop expand — only shown when sidebar is collapsed */}
            {!desktopOpen && (
              <button
                onClick={() => setDesktopOpen(true)}
                className={`hidden md:flex p-1.5 rounded-lg transition ${isDarkMode ? 'text-gray-300 hover:bg-gray-700' : 'text-gray-500 hover:bg-gray-100'}`}
                title="Show sidebar"
              >
                <Menu className="h-5 w-5" />
              </button>
            )}

            {/* Highlighted Admin Portal badge */}
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
              Admin Portal
            </span>
          </div>

          {/* Right: theme toggle + avatar dropdown */}
          <div className="flex items-center gap-2">
            {/* Dark / light toggle */}
            <button
              onClick={toggleDarkMode}
              className={`p-1.5 rounded-lg transition ${isDarkMode ? 'text-gray-300 hover:bg-gray-700' : 'text-gray-500 hover:bg-gray-100'}`}
              aria-label="Toggle theme"
            >
              {isDarkMode ? <Sun className="h-4.5 w-4.5" /> : <Moon className="h-4.5 w-4.5" />}
            </button>

            {/* Avatar dropdown */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button
                  className="flex items-center gap-2.5 rounded-full pr-1 pl-1 py-1 hover:bg-gray-100 dark:hover:bg-gray-700 transition outline-none"
                  aria-label="Admin menu"
                >
                  <InitialsAvatar name={ADMIN_NAME} />
                  <span className="hidden sm:block text-sm font-medium text-gray-700 dark:text-gray-200 max-w-[100px] truncate">
                    {ADMIN_NAME}
                  </span>
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-52">
                <DropdownMenuLabel className="font-normal">
                  <div className="flex items-center gap-2.5 py-1">
                    <InitialsAvatar name={ADMIN_NAME} size="lg" />
                    <div className="min-w-0">
                      <p className="text-sm font-semibold truncate">{ADMIN_NAME}</p>
                      <p className="text-xs text-gray-500 truncate">Super Admin</p>
                    </div>
                  </div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={toggleDarkMode}>
                  {isDarkMode
                    ? <><Sun className="mr-2 h-4 w-4" /> Light Mode</>
                    : <><Moon className="mr-2 h-4 w-4" /> Dark Mode</>
                  }
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={handleLogout} className="text-rose-600 focus:text-rose-600">
                  <LogOut className="mr-2 h-4 w-4" /> Log out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </header>

        {/* Page content */}
        <main className="p-4 sm:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default AdminLayout;
