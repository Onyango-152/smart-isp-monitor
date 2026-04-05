from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from monitoring.models import MonitoringTask
from devices.models import Device, DeviceType

User = get_user_model()


class MonitoringTaskAPITests(APITestCase):
	"""Integration tests for Monitoring Task endpoints."""

	def setUp(self):
		self.manager = User.objects.create_user(
			username='mgr_mon', password='Pass1234!', role='manager'
		)
		self.client.force_authenticate(user=self.manager)

		device_type = DeviceType.objects.create(name='Switch')
		self.device = Device.objects.create(
			name='Switch-1', ip_address='10.0.1.1',
			device_type=device_type, status='online',
		)
		self.task = MonitoringTask.objects.create(
			name='SNMP Poll Switch-1',
			device=self.device,
			task_type='snmp',
			interval=300,
		)

	# ── Task CRUD ─────────────────────────────────────────────────────────────

	def test_list_tasks_returns_200(self):
		res = self.client.get('/api/monitoring/tasks/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	def test_list_includes_created_task(self):
		res  = self.client.get('/api/monitoring/tasks/')
		data = res.data if isinstance(res.data, list) else res.data.get('results', [])
		ids  = [t['id'] for t in data]
		self.assertIn(self.task.id, ids)

	def test_create_task(self):
		res = self.client.post('/api/monitoring/tasks/', {
			'name': 'Ping Check', 'device': self.device.id,
			'task_type': 'ping', 'interval': 60,
		}, format='json')
		self.assertEqual(res.status_code, status.HTTP_201_CREATED)
		self.assertEqual(res.data['name'], 'Ping Check')

	def test_get_task_detail(self):
		res = self.client.get(f'/api/monitoring/tasks/{self.task.id}/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		self.assertEqual(res.data['id'], self.task.id)

	def test_update_task_interval(self):
		res = self.client.patch(
			f'/api/monitoring/tasks/{self.task.id}/',
			{'interval': 600}, format='json',
		)
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		self.task.refresh_from_db()
		self.assertEqual(self.task.interval, 600)

	def test_delete_task(self):
		res = self.client.delete(f'/api/monitoring/tasks/{self.task.id}/')
		self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
		self.assertFalse(MonitoringTask.objects.filter(pk=self.task.id).exists())

	# ── Run task ──────────────────────────────────────────────────────────────

	def test_run_task_returns_200(self):
		res = self.client.post(f'/api/monitoring/tasks/{self.task.id}/run/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		self.assertIn('message', res.data)

	def test_run_task_updates_last_run(self):
		self.client.post(f'/api/monitoring/tasks/{self.task.id}/run/')
		self.task.refresh_from_db()
		self.assertIsNotNone(self.task.last_run)

	def test_run_nonexistent_task_returns_404(self):
		res = self.client.post('/api/monitoring/tasks/99999/run/')
		self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

	# ── Health & stats ────────────────────────────────────────────────────────

	def test_health_endpoint_returns_200(self):
		res = self.client.get('/api/monitoring/health/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		self.assertIn('total_devices', res.data)

	def test_stats_endpoint_returns_200(self):
		res = self.client.get('/api/monitoring/stats/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		self.assertIn('total_tasks', res.data)
		self.assertIn('success_rate', res.data)

	# ── Auth ──────────────────────────────────────────────────────────────────

	def test_unauthenticated_gets_401(self):
		self.client.force_authenticate(user=None)
		res = self.client.get('/api/monitoring/tasks/')
		self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)
