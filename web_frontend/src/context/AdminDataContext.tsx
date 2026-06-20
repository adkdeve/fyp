import React, { createContext, useContext, useState, ReactNode } from 'react';

// Types
export interface Camera {
  id: string;
  name: string;
  location: string;
  siteIds?: string[];
  status: 'active' | 'inactive';
  resolution: string;
  ipAddress: string;
}

export interface SafetyOfficer {
  id: string;
  name: string;
  email: string;
  phone: string;
  siteIds?: string[];
  status: 'active' | 'inactive';
  joinDate: string;
}

export interface Site {
  id: string;
  name: string;
  location: string;
  cameraIds: string[];
  officerIds: string[];
  status: 'active' | 'inactive';
}

interface AdminDataContextType {
  // Cameras
  cameras: Camera[];
  addCamera: (camera: Camera) => void;
  updateCamera: (id: string, camera: Partial<Camera>) => void;
  deleteCamera: (id: string) => void;
  
  // Safety Officers
  officers: SafetyOfficer[];
  addOfficer: (officer: SafetyOfficer) => void;
  updateOfficer: (id: string, officer: Partial<SafetyOfficer>) => void;
  deleteOfficer: (id: string) => void;
  
  // Sites
  sites: Site[];
  addSite: (site: Site) => void;
  updateSite: (id: string, site: Partial<Site>) => void;
  deleteSite: (id: string) => void;
  
  // Assignment operations
  assignCameraToSite: (cameraId: string, siteId: string) => void;
  unassignCameraFromSite: (cameraId: string, siteId: string) => void;
  assignOfficerToSite: (officerId: string, siteId: string) => void;
  unassignOfficerFromSite: (officerId: string, siteId: string) => void;
}

const AdminDataContext = createContext<AdminDataContextType | undefined>(undefined);

// Dummy data
const DUMMY_CAMERAS: Camera[] = [
  {
    id: 'cam_001',
    name: 'Front Entrance Camera',
    location: 'Main Gate',
    status: 'active',
    resolution: '1080p',
    ipAddress: '192.168.1.101',
  },
  {
    id: 'cam_002',
    name: 'Warehouse Camera 1',
    location: 'Warehouse A',
    status: 'active',
    resolution: '2K',
    ipAddress: '192.168.1.102',
  },
  {
    id: 'cam_003',
    name: 'Warehouse Camera 2',
    location: 'Warehouse B',
    status: 'active',
    resolution: '1080p',
    ipAddress: '192.168.1.103',
  },
  {
    id: 'cam_004',
    name: 'Lab Area Camera',
    location: 'Research Lab',
    status: 'inactive',
    resolution: '4K',
    ipAddress: '192.168.1.104',
  },
  {
    id: 'cam_005',
    name: 'Office Corridor Camera',
    location: 'Office Building',
    status: 'active',
    resolution: '1080p',
    ipAddress: '192.168.1.105',
  },
];

const DUMMY_OFFICERS: SafetyOfficer[] = [
  {
    id: 'so_001',
    name: 'John Smith',
    email: 'john.smith@company.com',
    phone: '+1-555-0101',
    status: 'active',
    joinDate: '2024-01-15',
  },
  {
    id: 'so_002',
    name: 'Sarah Johnson',
    email: 'sarah.johnson@company.com',
    phone: '+1-555-0102',
    status: 'active',
    joinDate: '2024-02-20',
  },
  {
    id: 'so_003',
    name: 'Mike Williams',
    email: 'mike.williams@company.com',
    phone: '+1-555-0103',
    status: 'active',
    joinDate: '2024-01-10',
  },
  {
    id: 'so_004',
    name: 'Emily Brown',
    email: 'emily.brown@company.com',
    phone: '+1-555-0104',
    status: 'inactive',
    joinDate: '2023-12-01',
  },
];

const DUMMY_SITES: Site[] = [
  {
    id: 'site_001',
    name: 'Main Warehouse',
    location: 'Industrial Zone, City A',
    cameraIds: ['cam_001', 'cam_002'],
    officerIds: ['so_001'],
    status: 'active',
  },
  {
    id: 'site_002',
    name: 'Secondary Facility',
    location: 'Business District, City B',
    cameraIds: ['cam_003'],
    officerIds: ['so_002', 'so_003'],
    status: 'active',
  },
  {
    id: 'site_003',
    name: 'Research Center',
    location: 'Tech Park, City C',
    cameraIds: ['cam_004'],
    officerIds: [],
    status: 'inactive',
  },
];

export const AdminDataProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [cameras, setCameras] = useState<Camera[]>(DUMMY_CAMERAS);
  const [officers, setOfficers] = useState<SafetyOfficer[]>(DUMMY_OFFICERS);
  const [sites, setSites] = useState<Site[]>(DUMMY_SITES);

  // Camera operations
  const addCamera = (camera: Camera) => {
    setCameras([...cameras, camera]);
  };

  const updateCamera = (id: string, updates: Partial<Camera>) => {
    setCameras(cameras.map(cam => 
      cam.id === id ? { ...cam, ...updates } : cam
    ));
  };

  const deleteCamera = (id: string) => {
    setCameras(cameras.filter(cam => cam.id !== id));
    // Remove from all sites
    setSites(sites.map(site => ({
      ...site,
      cameraIds: site.cameraIds.filter(cid => cid !== id),
    })));
  };

  // Safety Officer operations
  const addOfficer = (officer: SafetyOfficer) => {
    setOfficers([...officers, officer]);
  };

  const updateOfficer = (id: string, updates: Partial<SafetyOfficer>) => {
    setOfficers(officers.map(off => 
      off.id === id ? { ...off, ...updates } : off
    ));
  };

  const deleteOfficer = (id: string) => {
    setOfficers(officers.filter(off => off.id !== id));
    // Remove from all sites
    setSites(sites.map(site => ({
      ...site,
      officerIds: site.officerIds.filter(oid => oid !== id),
    })));
  };

  // Site operations
  const addSite = (site: Site) => {
    setSites([...sites, site]);
  };

  const updateSite = (id: string, updates: Partial<Site>) => {
    setSites(sites.map(s => 
      s.id === id ? { ...s, ...updates } : s
    ));
  };

  const deleteSite = (id: string) => {
    setSites(sites.filter(s => s.id !== id));
  };

  const assignCameraToSite = (cameraId: string, siteId: string) => {
    // Update camera - add to siteIds array
    updateCamera(cameraId, { 
      siteIds: [...(cameras.find(c => c.id === cameraId)?.siteIds || []), siteId]
    });
    
    // Update site
    setSites(sites.map(site => {
      if (site.id === siteId && !site.cameraIds.includes(cameraId)) {
        return { ...site, cameraIds: [...site.cameraIds, cameraId] };
      }
      return site;
    }));
  };

  const unassignCameraFromSite = (cameraId: string, siteId: string) => {
    const camera = cameras.find(c => c.id === cameraId);
    if (camera?.siteIds) {
      // Remove from siteIds array
      const updatedSiteIds = camera.siteIds.filter(id => id !== siteId);
      updateCamera(cameraId, { siteIds: updatedSiteIds });
      
      // Remove from site
      setSites(sites.map(site => 
        site.id === siteId
          ? { ...site, cameraIds: site.cameraIds.filter(id => id !== cameraId) }
          : site
      ));
    }
  };

  const assignOfficerToSite = (officerId: string, siteId: string) => {
    // Update officer - add to siteIds array
    updateOfficer(officerId, { 
      siteIds: [...(officers.find(o => o.id === officerId)?.siteIds || []), siteId]
    });
    
    // Update site
    setSites(sites.map(site => {
      if (site.id === siteId && !site.officerIds.includes(officerId)) {
        return { ...site, officerIds: [...site.officerIds, officerId] };
      }
      return site;
    }));
  };

  const unassignOfficerFromSite = (officerId: string, siteId: string) => {
    const officer = officers.find(o => o.id === officerId);
    if (officer?.siteIds) {
      // Remove from siteIds array
      const updatedSiteIds = officer.siteIds.filter(id => id !== siteId);
      updateOfficer(officerId, { siteIds: updatedSiteIds });
      
      // Remove from site
      setSites(sites.map(site => 
        site.id === siteId
          ? { ...site, officerIds: site.officerIds.filter(id => id !== officerId) }
          : site
      ));
    }
  };

  return (
    <AdminDataContext.Provider
      value={{
        cameras,
        addCamera,
        updateCamera,
        deleteCamera,
        officers,
        addOfficer,
        updateOfficer,
        deleteOfficer,
        sites,
        addSite,
        updateSite,
        deleteSite,
        assignCameraToSite,
        unassignCameraFromSite,
        assignOfficerToSite,
        unassignOfficerFromSite,
      }}
    >
      {children}
    </AdminDataContext.Provider>
  );
};

export { AdminDataContext };
