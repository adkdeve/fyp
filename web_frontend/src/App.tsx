import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AdminDataProvider } from "@/context/AdminDataContext";
import { SiteDataProvider } from "@/context/SiteDataContext";
import { ThemeProvider } from "@/context/ThemeContext";

import HomePage from "./layouts/HomePage";

// Authentication pages
import LoginPage from "@/pages/auth/SiteLoginPage";
import AdminLoginPage from "@/pages/auth/AdminLoginPage";


// Company pages
import CompanyLayout from "@/layouts/SiteLayout";
import CompanyDashboard from "@/pages/site/TopNavigationPages/Dashboard";

// New page imports

import HistoryPage from "./pages/site/TopNavigationPages/HistoryPage";
import AnalyticsPage from "./pages/site/TopNavigationPages/AnalyticsPage";
import LiveView from "./pages/site/TopNavigationPages/LiveView";
import AlertsPage from "./pages/site/TopNavigationPages/AlertsPage";
// Admin pages
import AdminLayout from "@/layouts/AdminLayout";
import AdminDashboard from "@/pages/admin/AdminDashboard";


// Other
import NotFound from "@/NotFound";
import Dashboard from "@/pages/admin/AdminDashboard";
import VoilationDetails from "./pages/site/TopNavigationPages/VoilationDetails";
import AllCameras from "./pages/site/TopNavigationPages/AllCameras";
import Help from "./pages/site/BottomNavigationPages/Help";
import Settings from "./pages/site/BottomNavigationPages/Settings";
import Proflie from "./pages/site/BottomNavigationPages/Proflie";
import AddCamer from "./pages/admin/AddCamer";
import AssignCamera from "./pages/admin/AssignCamera";
import AssignSo from "./pages/admin/AssignSo";
import AddSO from "./pages/admin/AddSO";
import ManageSites from "./pages/admin/ManageSites";
import TermsConditions from "./pages/site/BottomNavigationPages/TermsConditions";
import ContactSupport from "./pages/site/BottomNavigationPages/ContactSupport";
import ProtectedRoute from "@/components/ProtectedRoute";
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 3 * 60 * 1000,   // 3 min
      gcTime: 10 * 60 * 1000,  // 10 min
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AdminDataProvider>
      <ThemeProvider>
        <TooltipProvider>
          <Toaster />
          <Sonner />
          <BrowserRouter>
            <Routes>

              {/* Home page */}
              <Route path="/" element={<HomePage />} />
              <Route path="/site/login" element={<LoginPage />} />
              <Route path="/admin/login" element={<AdminLoginPage />} />


              {/* Admin routes */}
              <Route path="/admin" element={<AdminLayout />}>
                <Route index element={<AdminDashboard />} />

                <Route path="sites" element={<ManageSites />} />
                <Route path="AddCamera" element={<AddCamer />} />
                <Route path="AssignCamera" element={<AssignCamera />} />
                <Route path="AssignSo" element={<AssignSo />} />
                <Route path="AddSo" element={<AddSO />} />

              </Route>


              {/* Site Routes */}
              <Route
                path="/site" element={<ProtectedRoute><SiteDataProvider><CompanyLayout /></SiteDataProvider></ProtectedRoute>}>

                <Route index element={<CompanyDashboard />} />
                <Route path="alerts" element={<AlertsPage />} />
                <Route path="history" element={<HistoryPage />} />
                <Route path="analytics" element={<AnalyticsPage />} />
                <Route path="camera/:id" element={<LiveView />} />
                <Route path="alert/:id" element={<VoilationDetails />} />
                <Route path="allcameras" element={<AllCameras />} />
                

                <Route path="profile" element={<Proflie />} />
                <Route path="setting" element={<Settings />} />

                <Route path="termsConditions" element={<TermsConditions />} />
                <Route path="help" element={<Help />} />
                <Route path="contact-support" element={<ContactSupport />} />


              </Route>

              {/* 404 route */}
              <Route path="*" element={<NotFound />} />


            </Routes>
          </BrowserRouter>
        </TooltipProvider>
      </ThemeProvider>
    </AdminDataProvider>
  </QueryClientProvider>
);

export default App;
