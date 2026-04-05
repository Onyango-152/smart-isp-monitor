from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator

class CustomUser(AbstractUser):
    """
    Extended User model with a single canonical `role` field that drives
    all routing and permission logic.  The legacy `is_technician` /
    `is_sales` booleans are kept as computed properties so older code
    that references them still works.
    """

    # ── Role choices ────────────────────────────────────────────────────
    CUSTOMER   = 'customer'
    TECHNICIAN = 'technician'
    MANAGER    = 'manager'
    ADMIN      = 'admin'

    ROLE_CHOICES = [
        (CUSTOMER,   'Customer'),
        (TECHNICIAN, 'Technician'),
        (MANAGER,    'Manager'),
        (ADMIN,      'Admin'),
    ]

    role         = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default=CUSTOMER,
        db_index=True,
    )
    phone        = models.CharField(max_length=20, blank=True, null=True)
    organization = models.CharField(max_length=255, blank=True, null=True)
    email_verified = models.BooleanField(default=False)
    email_otp_hash = models.CharField(max_length=128, blank=True, null=True)
    email_otp_expires_at = models.DateTimeField(null=True, blank=True)
    email_otp_sent_at = models.DateTimeField(null=True, blank=True)
    email_otp_send_count = models.IntegerField(default=0)
    email_otp_attempts = models.IntegerField(default=0)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    # ── Backward-compat properties (kept so older admin/query code works) ──
    @property
    def is_technician(self):
        return self.role == self.TECHNICIAN

    @property
    def is_sales(self):
        return False  # not used in the new role system

    class Meta:
        ordering = ['-date_joined']
        verbose_name = 'User'
        verbose_name_plural = 'Users'

    def __str__(self):
        return f"{self.get_full_name() or self.username} ({self.role})"
