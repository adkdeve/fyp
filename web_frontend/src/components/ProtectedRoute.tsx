import React from 'react';
import { Navigate } from 'react-router-dom';
import { getSiteOfficerSession } from '@/lib/authSession';

interface ProtectedRouteProps {
  children: JSX.Element;
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ children }) => {
  const token = localStorage.getItem('token');
  const officerData = getSiteOfficerSession();
  const siteData = localStorage.getItem('site');

  if (!token && !officerData && !siteData) {
    return <Navigate to="/site/login" replace />;
  }

  return children;
};

export default ProtectedRoute;