import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Video, Users, Camera, Loader2, Search, X } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useTheme } from '@/context/ThemeContext';
import { getAllCameras, getCamerasBySite, updateCamera, type Camera as CameraType } from '@/lib/firebaseCameras';
import api from '@/lib/api';
import { syncSiteOfficerSession } from '@/lib/authSession';
import CameraStream from '@/components/CameraStream';

export default function AllCameras() {
	const { isDarkMode } = useTheme();
	const [loading, setLoading] = useState(true);
	const [cameras, setCameras] = useState<CameraType[]>([]);
	const { toast } = useToast();

	useEffect(() => {
		const loadCameras = async () => {
			try {
				// Load cameras assigned to supervisor's sites
				const officer = await syncSiteOfficerSession();
				if (officer) {
					const siteIds: string[] = officer.siteIds || [];
					const allCamsById: Record<string, CameraType> = {};
					for (const siteId of siteIds) {
						const cams = await getCamerasBySite(siteId);
						for (const cam of cams) {
							if (cam.id) allCamsById[cam.id] = cam;
						}
					}
					setCameras(Object.values(allCamsById));
				} else {
					// Fallback: load all cameras
					const allCams = await getAllCameras();
					setCameras(allCams);
				}
			} catch (error) {
				console.error('Failed to load cameras:', error);
			} finally {
				setLoading(false);
			}
		};
		loadCameras();
	}, []);

	if (loading) {
		return (
			<div className={`flex justify-center items-center h-48 ${isDarkMode ? 'text-gray-300' : ''}`}>
				<Loader2 className="h-8 w-8 animate-spin text-primary" />
				<p className="ml-3">Loading cameras...</p>
			</div>
		);
	}

	const toggleCamera = async (cam: CameraType) => {
		try {
			const newStatus = !cam.enabled;
			await updateCamera(cam.id!, { enabled: newStatus });
			if (newStatus) {
				await api.startCamera(cam.id!, cam.rtsp_url);
				toast({ title: 'Camera Started', description: `Live feed for ${cam.name} is now running.` });
			} else {
				await api.stopCamera(cam.id!);
				toast({ title: 'Camera Stopped', description: `Live feed for ${cam.name} stopped.` });
			}
			setCameras(prev => prev.map(c => c.id === cam.id ? { ...c, enabled: newStatus } : c));
		} catch (error) {
			toast({ variant: 'destructive', title: 'Error', description: 'Failed to toggle camera state.' });
		}
	};

	const enabledCount = cameras.filter(c => c.enabled).length;
	const disabledCount = cameras.filter(c => !c.enabled).length;

	return (
		<div className="space-y-6 px-4 md:px-6">
			<div>
				<h1 className={`text-2xl md:text-3xl font-extrabold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>Camera Management</h1>
				<p className={`mt-1 text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>{cameras.length} cameras assigned to your sites</p>
			</div>

			{/* Status summary */}
			<div className="grid grid-cols-1 md:grid-cols-3 gap-4">
				<div className={`rounded-lg p-4 border ${isDarkMode ? 'bg-emerald-900/30 border-emerald-800' : 'bg-emerald-50 border-emerald-200'}`}>
					<div className={`text-sm ${isDarkMode ? 'text-emerald-400' : 'text-emerald-700'}`}>Enabled</div>
					<div className={`mt-2 text-3xl font-bold ${isDarkMode ? 'text-emerald-400' : 'text-emerald-600'}`}>{enabledCount}</div>
				</div>
				<div className={`rounded-lg p-4 border ${isDarkMode ? 'bg-blue-900/30 border-blue-800' : 'bg-blue-50 border-blue-200'}`}>
					<div className={`text-sm ${isDarkMode ? 'text-blue-400' : 'text-blue-700'}`}>Total</div>
					<div className={`mt-2 text-3xl font-bold ${isDarkMode ? 'text-blue-400' : 'text-blue-600'}`}>{cameras.length}</div>
				</div>
				<div className={`rounded-lg p-4 border ${isDarkMode ? 'bg-rose-900/30 border-rose-800' : 'bg-rose-50 border-rose-200'}`}>
					<div className={`text-sm ${isDarkMode ? 'text-rose-400' : 'text-rose-700'}`}>Disabled</div>
					<div className={`mt-2 text-3xl font-bold ${isDarkMode ? 'text-rose-400' : 'text-rose-600'}`}>{disabledCount}</div>
				</div>
			</div>

			{/* Camera list */}
			{cameras.length === 0 ? (
				<div className={`text-center py-12 rounded-lg border ${isDarkMode ? 'bg-gray-800 border-gray-700 text-gray-400' : 'bg-white border-gray-200 text-gray-500'}`}>
					No cameras assigned to your sites. Contact your administrator.
				</div>
			) : (
				<div className="space-y-4">
					{cameras.map((cam) => (
						<Link to={`/site/camera/${cam.id}`} key={cam.id}
							className={`block rounded-lg border p-6 space-y-4 hover:shadow-lg transition ${isDarkMode ? 'bg-gray-800 border-gray-700 hover:border-gray-600' : 'bg-white border-gray-200 hover:border-gray-300'}`}>
							{/* Header */}
							<div className="flex items-start justify-between">
								<div className="flex-1">
									<div className="flex items-center gap-2">
										<h3 className={`text-lg font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>{cam.name}</h3>
										<span className={`text-xs px-2 py-1 rounded-full font-medium ${
											cam.enabled ? isDarkMode ? 'bg-emerald-900/50 text-emerald-400' : 'bg-emerald-100 text-emerald-700'
											: isDarkMode ? 'bg-rose-900/50 text-rose-400' : 'bg-rose-100 text-rose-700'
										}`}>
											{cam.enabled ? 'enabled' : 'disabled'}
										</span>
									</div>
									<div className={`mt-2 text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
										<div>Location: {cam.location}</div>
										<div className="text-xs font-mono truncate mt-1">Stream: {cam.rtsp_url}</div>
									</div>
								</div>
							</div>

							{/* Video preview */}
							<div className={`rounded-lg h-64 relative flex items-center justify-center border overflow-hidden ${isDarkMode ? 'bg-gray-900 border-gray-600' : 'bg-gray-900 border-gray-300'}`}>
								{cam.enabled ? (
									<CameraStream
										cameraId={cam.id!}
										className="w-full h-full object-cover"
										refreshInterval={100}
									/>
								) : null}
								<div className="absolute left-3 top-3 bg-red-600 text-white text-xs px-2 py-1 rounded-full font-bold">LIVE</div>
								{!cam.enabled && (
									<Camera className={`h-16 w-16 opacity-20 absolute ${isDarkMode ? 'text-gray-500' : 'text-gray-600'}`} />
								)}
							</div>
							<div className="flex gap-2 mt-4">
								<button
									onClick={(e) => { e.preventDefault(); toggleCamera(cam); }}
									className={`flex-1 py-2 rounded font-semibold text-white transition ${cam.enabled ? 'bg-rose-600 hover:bg-rose-700' : 'bg-emerald-600 hover:bg-emerald-700'}`}
								>
									{cam.enabled ? 'Stop Live Feed' : 'Start Live Feed'}
								</button>
							</div>
						</Link>
					))}
				</div>
			)}
		</div>
	);
}
