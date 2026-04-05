from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from metrics.models import Metric, MetricReading
from devices.models import Device, DeviceType

User = get_user_model()


class MetricSnapshotAPITests(APITestCase):
	"""Integration tests for the Metrics (snapshot + readings) API."""

	def setUp(self):
		self.manager = User.objects.create_user(
			username='mgr_metric', password='Pass1234!', role='manager'
		)
		self.client.force_authenticate(user=self.manager)

		device_type = DeviceType.objects.create(name='Firewall')
		self.device = Device.objects.create(
			name='FW-1', ip_address='10.0.2.1',
			device_type=device_type, status='online',
		)
		self.metric  = Metric.objects.create(name='latency_ms', unit='ms')
		self.reading = MetricReading.objects.create(
			device=self.device, metric=self.metric, value=22.5
		)

	# ── Snapshot list ─────────────────────────────────────────────────────────

	def test_all_snapshots_returns_200(self):
		res = self.client.get('/api/metrics/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	def test_all_snapshots_returns_list(self):
		res = self.client.get('/api/metrics/')
		self.assertIsInstance(res.data, list)

	def test_device_snapshot_filters_correctly(self):
		res = self.client.get(f'/api/metrics/?device={self.device.id}')
		self.assertEqual(res.status_code, status.HTTP_200_OK)
		self.assertEqual(len(res.data), 1)
		self.assertEqual(res.data[0]['id'], self.device.id)

	def test_snapshot_exposes_latency_field(self):
		res = self.client.get(f'/api/metrics/?device={self.device.id}')
		self.assertIn('latency_ms', res.data[0])
		self.assertEqual(res.data[0]['latency_ms'], 22.5)

	# ── Readings CRUD ─────────────────────────────────────────────────────────

	def test_readings_list_returns_200(self):
		res = self.client.get('/api/metrics/readings/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	def test_create_metric_reading(self):
		res = self.client.post('/api/metrics/readings/', {
			'device': self.device.id,
			'metric': self.metric.id,
			'value': 35.0,
		}, format='json')
		self.assertEqual(res.status_code, status.HTTP_201_CREATED)
		self.assertEqual(res.data['value'], 35.0)

	# ── Device metrics view ───────────────────────────────────────────────────

	def test_device_metrics_returns_200(self):
		res = self.client.get(f'/api/metrics/device/{self.device.id}/')
		self.assertEqual(res.status_code, status.HTTP_200_OK)

	# ── Auth ──────────────────────────────────────────────────────────────────

	def test_unauthenticated_gets_401(self):
		self.client.force_authenticate(user=None)
		res = self.client.get('/api/metrics/')
		self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)
