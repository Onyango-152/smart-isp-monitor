from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import CustomUser


@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    """
    Custom User Admin Interface
    Extends Django's default UserAdmin to display custom user fields.
    """
    fieldsets = BaseUserAdmin.fieldsets + (
        ('ISP Specific Information', {
            'fields': ('phone', 'organization', 'is_technician', 'is_sales')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    readonly_fields = ('created_at', 'updated_at')
    list_display = ('username', 'email', 'get_full_name', 'organization', 'is_technician', 'is_staff')
    list_filter = BaseUserAdmin.list_filter + ('is_technician', 'is_sales', 'organization')
    search_fields = ('username', 'email', 'first_name', 'last_name', 'organization')

