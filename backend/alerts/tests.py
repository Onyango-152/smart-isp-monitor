from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from alerts.models import Alert, AlertRule
from devices.models import Device, DeviceType
from metrics.models import Metric

User = get_user_model()


class AlertAPITests(APITestCase):
	"""Integration tests for the Alerts REST API."""

	def setUp(self):
		self.manager = User.objects.create_user(
			username='mgr_alert', password='Pass1234!', role='manager'
		)
		self.client.force_authenticate(user=self.manager)

		device_type  = DeviceType.objects.create(name='Router')
		self.device  = Device.objects.create(
			name='Router-1', ip_address='10.0.0.1',
			device_type=device_type, status='online',
		)
		self.metric = Metric.objects.create(name='latency_test', unit='ms')
		self.rule   = AlertRule.objects.create(
			name='High Latency', device=self.device, metric=self.metric,
			condition='gt', threshold=100.0, severity='high', enabled=True,
		)
		self.alert = Alert.objects.create(
			rule=self.rule, device=self.device,
			severity='high', status='new', message='Test alert',
		)

	# ── List & filter ─────────────────────────────────────────────────────────

	def test_list_alerts_returns_200(self):
		res = self.client.get('/api/alerts/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	def test_list_includes_created_alert(self):
		res    = self.client.get('/api/alerts/')
		data   = res.data if isinstance(res.data, list) else res.data.get('results', [])
		ids    = [item['id'] for item in data]
		self.assertIn(self.alert.id, ids)

	def test_filter_by_status_new(self):
		res  = self.client.get('/api/alerts/?status=new')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		data = res.data if isinstance(res.data, list) else res.data.get('results', [])
		for item in data:
			self.assertEqual(item['status'], 'new')

	def test_filter_by_device(self):
		res = self.client.get(f'/api/alerts/?device={self.device.id}')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	# ── Detail ────────────────────────────────────────────────────────────────

	def test_get_alert_detail(self):
		res = self.client.get(f'/api/alerts/{self.alert.id}/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		self.assertEqual(res.data['id'], self.alert.id)

	# ── Acknowledge ───────────────────────────────────────────────────────────

	def test_acknowledge_alert_returns_200(self):
		res = self.client.post(f'/api/alerts/{self.alert.id}/acknowledge/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	def test_acknowledge_changes_status(self):
		self.client.post(f'/api/alerts/{self.alert.id}/acknowledge/')
		self.alert.refresh_from_db()
		self.assertEqual(self.alert.status, 'acknowledged')

	def test_acknowledge_sets_acknowledged_at(self):
		self.client.post(f'/api/alerts/{self.alert.id}/acknowledge/')
		self.alert.refresh_from_db()
		self.assertIsNotNone(self.alert.acknowledged_at)

	# ── Resolve ───────────────────────────────────────────────────────────────

	def test_resolve_alert_returns_200(self):
		res = self.client.post(f'/api/alerts/{self.alert.id}/resolve/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	def test_resolve_changes_status(self):
		self.client.post(f'/api/alerts/{self.alert.id}/resolve/')
		self.alert.refresh_from_db()
		self.assertEqual(self.alert.status, 'resolved')

	def test_resolve_sets_resolved_at(self):
		self.client.post(f'/api/alerts/{self.alert.id}/resolve/')
		self.alert.refresh_from_db()
		self.assertIsNotNone(self.alert.resolved_at)

	# ── Auth ──────────────────────────────────────────────────────────────────

	def test_unauthenticated_gets_401(self):
		self.client.force_authenticate(user=None)
		res = self.client.get('/api/alerts/')
		self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

	def test_customer_my_alerts_returns_200(self):
		customer = User.objects.create_user(
			username='cust_test', password='Pass1234!', role='customer'
		)
		self.client.force_authenticate(user=customer)
		res = self.client.get('/api/alerts/my-alerts/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
