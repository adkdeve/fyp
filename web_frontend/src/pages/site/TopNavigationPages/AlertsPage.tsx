import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { AlertTriangle, Eye, X, Clock, Loader2 } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useTheme } from '@/context/ThemeContext';
import { updateViolationStatus } from '@/lib/firebaseViolations';
import { useSiteData } from '@/context/SiteDataContext';

export default function AlertsPage() {
	const { isDarkMode } = useTheme();
	const [query, setQuery] = useState('');
	const [priorityFilter, setPriorityFilter] = useState<'ALL' | 'HIGH' | 'MEDIUM' | 'LOW'>('ALL');
	const { toast } = useToast();
	const { loading, cameras, violations } = useSiteData();

	const myViolations = useMemo(() => {
		const cameraIds = cameras.map(c => c.id);
		return violations.filter(v => cameraIds.includes(v.camera_id) && v.status === 'open');
	}, [violations, cameras]);

	const formatTime = (isoStr: string) => {
		const d = new Date(isoStr);
		const diffMs = Date.now() - d.getTime();
		const diffMins = Math.floor(diffMs / 60000);
		if (diffMins < 60) return `${diffMins} min ago`;
		const diffHours = Math.floor(diffMins / 60);
		if (diffHours < 24) return `${diffHours} hr ago`;
		return d.toLocaleDateString();
	};

	const alerts = useMemo(
		() =>
			myViolations.filter((v) => {
				const title = v.type.replace(/_/g, ' ').toUpperCase();
				const camName = v.camera_name || 'Unknown Zone';
				const priority = v.severity.toUpperCase();
				
				return (title.includes(query.toUpperCase()) || camName.toUpperCase().includes(query.toUpperCase())) &&
					(priorityFilter === 'ALL' || priority === priorityFilter);
			}).map(v => ({
				id: v.id,
				badge: v.type.includes('unauthorized') ? 'Unauthorized' : v.type.includes('material') ? 'Hazard' : 'PPE',
				priority: v.severity.toUpperCase(),
				title: v.type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
				zone: v.camera_name || 'Camera ' + v.camera_id.substring(0,6),
				time: formatTime(v.detected_at),
			})),
		[myViolations, query, priorityFilter]
	);

	const counts = useMemo(() => {
		return {
			all: alerts.length,
			high: alerts.filter((a) => a.priority === 'HIGH').length,
			medium: alerts.filter((a) => a.priority === 'MEDIUM').length,
			low: alerts.filter((a) => a.priority === 'LOW').length,
		};
	}, [alerts]);

	const handleDismissAlert = async (id: string) => {
		try {
			await updateViolationStatus(id, 'dismissed');
			toast({
				title: 'Alert Dismissed',
				description: 'Alert has been marked as reviewed.',
			});
		} catch (e) {
			toast({ variant: 'destructive', title: 'Error', description: 'Failed to dismiss alert' });
		}
	};

	const handleAcknowledgeAlert = async (id: string) => {
		try {
			await updateViolationStatus(id, 'acknowledged');
			toast({
				title: 'Alert Acknowledged',
				description: 'Alert action has been recorded.',
			});
		} catch (e) {
			toast({ variant: 'destructive', title: 'Error', description: 'Failed to acknowledge alert' });
		}
	};

	const PriorityBadge = ({ p }: { p: string }) => {
		const classes =
			p === 'HIGH'
				? 'bg-rose-100 text-rose-700'
				: p === 'MEDIUM'
				? 'bg-amber-100 text-amber-700'
				: 'bg-blue-100 text-blue-700';
		return (
			<span className={`text-xs font-medium px-5 py-1 rounded-full ${classes}`}>
				{p}
			</span>
		);
	};

	if (loading) {
		return (
			<div className={`flex justify-center items-center h-64 ${isDarkMode ? 'text-gray-300' : ''}`}>
				<Loader2 className="h-8 w-8 animate-spin text-primary" />
				<p className="ml-2">Loading alerts...</p>
			</div>
		);
	}

	return (
		<div className="space-y-6 px-4 md:px-6">
			{/* Header */}
			<div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
				<div>
					<h1 className={`text-2xl md:text-3xl font-extrabold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
						Active Alerts
					</h1>
					<p className={`mt-1 text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
						{counts.all} violations requiring attention
					</p>
				</div>

				<div className="flex items-center gap-3">
					<div className="relative">
						<input
							value={query}
							onChange={(e) => setQuery(e.target.value)}
							placeholder="Search alerts..."
							className={`w-64 md:w-80 rounded-md px-3 py-2 text-sm placeholder:text-gray-400 focus:outline-none focus:ring-0 ${isDarkMode ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300 text-gray-900'} border`}
						/>
						<div className={`absolute right-2 top-2 ${isDarkMode ? 'text-gray-500' : 'text-gray-400'}`}>
							<svg
								className="h-4 w-4"
								viewBox="0 0 24 24"
								fill="none"
								stroke="currentColor"
							>
								<path
									strokeLinecap="round"
									strokeLinejoin="round"
									strokeWidth="2"
									d="M21 21l-4.35-4.35M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16z"
								/>
							</svg>
						</div>
					</div>
				</div>
			</div>

		{/* Priority Filter Buttons */}
		<div className="flex gap-2 flex-wrap">
			{(['ALL', 'HIGH', 'MEDIUM', 'LOW'] as const).map((priority) => (
				<button
					key={priority}
					onClick={() => setPriorityFilter(priority)}
					className={`px-3 py-1 rounded-full text-xs font-medium transition ${
						priorityFilter === priority
							? priority === 'ALL'
								? 'bg-blue-600 text-white'
								: priority === 'HIGH'
								? 'bg-rose-600 text-white'
								: priority === 'MEDIUM'
								? 'bg-amber-500 text-white'
								: 'bg-blue-600 text-white'
							: isDarkMode ? 'bg-gray-700 text-gray-300 hover:bg-gray-600' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
					}`}
				>
					{priority}
				</button>
			))}
		</div>			{/* Summary metric boxes */}
			<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
				<div className={`rounded-xl p-6 border ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
					<div className={`text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>All Alerts</div>
					<div className={`mt-3 text-3xl font-bold ${isDarkMode ? 'text-blue-400' : 'text-blue-600'}`}>
						{counts.all}
					</div>
				</div>
				<div className={`rounded-xl p-6 border ${isDarkMode ? 'bg-rose-900/30 border-rose-800' : 'bg-rose-50 border-rose-200'}`}>
					<div className={`text-sm ${isDarkMode ? 'text-rose-400' : 'text-rose-700'}`}>High Priority</div>
					<div className={`mt-3 text-3xl font-bold ${isDarkMode ? 'text-rose-400' : 'text-rose-600'}`}>
						{counts.high}
					</div>
				</div>
				<div className={`rounded-xl p-6 border ${isDarkMode ? 'bg-amber-900/30 border-amber-800' : 'bg-amber-50 border-amber-200'}`}>
					<div className={`text-sm ${isDarkMode ? 'text-amber-400' : 'text-amber-700'}`}>Medium Priority</div>
					<div className={`mt-3 text-3xl font-bold ${isDarkMode ? 'text-amber-400' : 'text-amber-600'}`}>
						{counts.medium}
					</div>
				</div>
				<div className={`rounded-xl p-6 border ${isDarkMode ? 'bg-blue-900/30 border-blue-800' : 'bg-blue-50 border-blue-200'}`}>
					<div className={`text-sm ${isDarkMode ? 'text-blue-400' : 'text-blue-700'}`}>Low Priority</div>
					<div className={`mt-3 text-3xl font-bold ${isDarkMode ? 'text-blue-400' : 'text-blue-600'}`}>
						{counts.low}
					</div>
				</div>
			</div>

			{/* Alerts list */}
			<div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
				{alerts.length > 0 ? (
					alerts.map((a) => {
						const isHigh = a.priority === 'HIGH';
						const isMed = a.priority === 'MEDIUM';
					const toneBorder = isHigh
						? isDarkMode ? 'border-rose-800' : 'border-rose-200'
						: isMed
						? isDarkMode ? 'border-amber-800' : 'border-amber-200'
						: isDarkMode ? 'border-blue-800' : 'border-blue-200';
					const toneBg = isHigh
						? isDarkMode ? 'bg-rose-900/20' : 'bg-rose-50'
						: isMed
						? isDarkMode ? 'bg-amber-900/20' : 'bg-amber-50'
						: isDarkMode ? 'bg-blue-900/20' : 'bg-blue-50';
						const tagBg = isHigh
							? 'bg-rose-600 text-white'
							: isMed
							? 'bg-amber-500 text-white'
							: 'bg-blue-600 text-white';

						return (
							<div
								key={a.id}
								className={`relative rounded-lg p-4 ${toneBg} border ${toneBorder} shadow-sm`}
							>
							<button
								onClick={() => handleDismissAlert(a.id)}
								className={`absolute right-3 top-3 cursor-pointer transition ${isDarkMode ? 'text-gray-500 hover:text-gray-400' : 'text-gray-400 hover:text-gray-600'}`}
							>
								<X size={18} />
							</button>								<div className="flex items-start justify-between gap-4">
									<div className="flex-1">
									<div className="flex items-center gap-2 mb-2">
										<div className={`text-xs px-2 py-1 rounded-full flex items-center gap-2 ${isDarkMode ? 'bg-gray-700 text-gray-300' : 'bg-gray-100 text-gray-700'}`}>
											<AlertTriangle className={`h-4 w-4 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`} />
											<span className="font-medium">{a.badge}</span>
										</div>
											<div
												className={`text-xs px-2 py-1 rounded-full ${tagBg} ml-1`}
											>
												{a.priority}
											</div>
										</div>

									<div className={`text-lg font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
										{a.title}
									</div>
									<div className={`mt-2 text-sm flex items-center gap-3 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
										<span className="flex items-center gap-1">
											{/* <svg
												className={`h-4 w-4 ${isDarkMode ? 'text-gray-500' : 'text-gray-500'}`}
												viewBox="0 0 24 24"
												fill="none"
												stroke="currentColor"
											>
												<path
													strokeLinecap="round"
													strokeLinejoin="round"
													strokeWidth="2"
													d="M12 8v4l3 3"
												/>
											</svg> */}
											{a.zone}
										</span>
										<span className="flex items-center gap-1">
											<Clock className={`h-4 w-4 ${isDarkMode ? 'text-gray-500' : 'text-gray-500'}`} />
											{a.time}
										</span>
									</div>										<div className="mt-4 flex items-center gap-3">
											<Link
												to={`/site/alert/${a.id}`}
												className={`flex items-center gap-2 px-4 py-2 rounded-md border transition ${isDarkMode ? 'bg-gray-700 border-gray-600 text-gray-300 hover:bg-gray-600' : 'bg-gray-100 border-gray-300 text-gray-700 hover:bg-gray-200'}`}
											>
												<Eye className="h-4 w-4" /> View Details
											</Link>
											<button
												onClick={() => handleAcknowledgeAlert(a.id)}
												className={`px-4 py-2 rounded-md font-medium text-white transition ${
													isHigh
														? 'bg-rose-600 hover:bg-rose-700'
														: isMed
														? 'bg-amber-500 hover:bg-amber-600'
														: 'bg-blue-600 hover:bg-blue-700'
												}`}
											>
												Acknowledge
											</button>
										</div>
									</div>
									<div className="hidden md:flex flex-col items-end">
										<div className="mt-5">
											<PriorityBadge p={a.priority} />
										</div>
									</div>
								</div>
							</div>
						);
					})
				) : (
					<div className="col-span-2 text-center py-12">
						<AlertTriangle className="h-12 w-12 mx-auto mb-4 opacity-30 text-gray-400" />
						<p className="text-gray-500 text-lg">No alerts found</p>
						<p className="text-gray-400 text-sm mt-1">All violations have been reviewed or don't match your filters</p>
					</div>
				)}
			</div>
		</div>
	);
}
