from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import CustomUser


@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    """
    Custom User Admin Interface.
    Uses the new canonical `role` field instead of the removed boolean flags.
    """
    # Add `role` to the standard fieldsets so it appears on the edit form
    fieldsets = BaseUserAdmin.fieldsets + (
        ('ISP Information', {
            'fields': ('role', 'phone', 'organization'),
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )
    # Also expose role when creating a user via the admin
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Role & Organisation', {
            'fields': ('role', 'email', 'phone', 'organization'),
        }),
    )
    readonly_fields = ('created_at', 'updated_at')
    list_display    = ('username', 'email', 'get_full_name', 'role', 'organization', 'is_staff')
    list_filter     = BaseUserAdmin.list_filter + ('role', 'organization')
    search_fields   = ('username', 'email', 'first_name', 'last_name', 'organization')

