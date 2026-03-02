from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator

class CustomUser(AbstractUser):
    """
    Extended User model with additional fields specific to ISP monitoring.
    This replaces Django's default User model to add custom functionality.
    
    Fields:
    - phone: Contact phone number
    - organization: Company/ISP name the user belongs to
    - is_technician: Boolean flag to identify service technicians
    - is_sales: Boolean flag to identify sales staff
    """
    phone = models.CharField(max_length=20, blank=True, null=True)
    organization = models.CharField(max_length=255, blank=True, null=True)
    is_technician = models.BooleanField(default=False)
    is_sales = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-date_joined']
        verbose_name = 'User'
        verbose_name_plural = 'Users'

    def __str__(self):
        return f"{self.get_full_name()} ({self.username})"
