import React from "react";
import { Navigate, useLocation } from "react-router-dom";

const AdminProtectedRoute = ({ children }: { children: React.ReactNode }) => {
  const location = useLocation();
  const adminToken = localStorage.getItem("admin");

  if (!adminToken) {
    // Redirect to admin login if no token
    return <Navigate to="/admin/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
};

export default AdminProtectedRoute;