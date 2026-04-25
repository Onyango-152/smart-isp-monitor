from django.db import models
from django.contrib.auth import get_user_model
import secrets

User = get_user_model()


class Organisation(models.Model):
    name        = models.CharField(max_length=255)
    slug        = models.SlugField(max_length=255, unique=True)
    description = models.TextField(blank=True, null=True)
    created_by  = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True,
        related_name='owned_organisations',
    )
    is_active  = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering     = ['name']
        verbose_name = 'Organisation'
        verbose_name_plural = 'Organisations'

    def __str__(self):
        return self.name


class Membership(models.Model):
    ROLE_CHOICES = [
        ('manager',    'Manager'),
        ('technician', 'Technician'),
        ('customer',   'Customer'),
    ]

    organisation = models.ForeignKey(Organisation, on_delete=models.CASCADE, related_name='memberships')
    user         = models.ForeignKey(User, on_delete=models.CASCADE, related_name='memberships')
    role         = models.CharField(max_length=20, choices=ROLE_CHOICES)
    invited_by   = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='sent_invitations',
    )
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('organisation', 'user')
        verbose_name    = 'Membership'
        verbose_name_plural = 'Memberships'

    def __str__(self):
        return f"{self.user.username} @ {self.organisation.name} ({self.role})"


class Invitation(models.Model):
    """
    Pending invitation sent by a manager to a user (by email).
    The invited user may not have an account yet — we store email.
    Token is a secure random string used in the accept/decline link.
    """
    STATUS_CHOICES = [
        ('pending',   'Pending'),
        ('accepted',  'Accepted'),
        ('declined',  'Declined'),
        ('cancelled', 'Cancelled'),
        ('expired',   'Expired'),
    ]
    ROLE_CHOICES = Membership.ROLE_CHOICES

    organisation = models.ForeignKey(Organisation, on_delete=models.CASCADE, related_name='invitations')
    invited_by   = models.ForeignKey(User, on_delete=models.CASCADE, related_name='invitations_sent')
    email        = models.EmailField()
    role         = models.CharField(max_length=20, choices=ROLE_CHOICES, default='technician')
    token        = models.CharField(max_length=64, unique=True, editable=False)
    status       = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at   = models.DateTimeField(auto_now_add=True)
    expires_at   = models.DateTimeField()
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Invitation'
        verbose_name_plural = 'Invitations'

    def save(self, *args, **kwargs):
        if not self.token:
            self.token = secrets.token_urlsafe(48)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        from django.utils import timezone
        return self.expires_at < timezone.now()

    def __str__(self):
        return f"Invite {self.email} → {self.organisation.name} ({self.status})"
