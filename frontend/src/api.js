import axios from 'axios';

const api = axios.create({
    baseURL: import.meta.env.VITE_API_URL || "http://localhost:8000",
});

// Dashboard
export const getDashboard = () => api.get('/dashboard');
export const refreshDashboard = () => api.post('/dashboard/refresh');
export const takeSnapshot = () => api.post('/dashboard/snapshot');
export const recordSpend = (data) => api.post('/dashboard/spend', data);

// Requests
export const submitRequest = (data) => api.post('/requests/', data);
export const decideStage = (id, data) => api.post(`/requests/${id}/decide`, data);
export const getSlaStatus = (id) => api.get(`/requests/${id}/sla`);
export const escalateOverdue = () => api.post('/requests/escalate');

// Incidents
export const logIncident = (data) => api.post('/incidents/', data);
export const resolveIncident = (id, data) => api.patch(`/incidents/${id}/resolve`, data);

// Tasks
export const assignTask = (data) => api.post('/tasks/', data);
export const completeTask = (id, actorId) => api.patch(`/tasks/${id}/complete`, { actor_id: actorId });
export const cancelTask = (id, actorId) => api.patch(`/tasks/${id}/cancel`, { actor_id: actorId });
export const reopenTask = (id, actorId) => api.patch(`/tasks/${id}/reopen`, { actor_id: actorId });

// Reports
export const getEfficiency = () => api.get('/reports/efficiency');
export const getWorkload = () => api.get('/reports/workload');
export const getIncidentTrend = () => api.get('/reports/incidents/trend');
export const getBottleneck = () => api.get('/reports/bottleneck');
export const getBudget = () => api.get('/reports/budget');
export const getAging = () => api.get('/reports/aging');
export const getKpiTrend = () => api.get('/reports/kpi-trend');