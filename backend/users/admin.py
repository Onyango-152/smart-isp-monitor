from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import CustomUser


class MembershipInline(admin.TabularInline):
    from organisations.models import Membership
    model           = Membership
    fk_name         = 'user'  # Specify which ForeignKey to use
    extra           = 0
    fields          = ('organisation', 'role', 'joined_at')
    readonly_fields = ('joined_at',)


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
        ('Email Verification', {
            'fields': ('email_verified',),
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
    list_display    = ('username', 'email', 'get_full_name', 'role', 'organization', 'email_verified', 'is_staff')
    list_filter     = BaseUserAdmin.list_filter + ('role', 'organization')
    search_fields   = ('username', 'email', 'first_name', 'last_name', 'organization')
    inlines         = [MembershipInline]

