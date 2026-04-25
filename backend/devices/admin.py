from django.contrib import admin
from .models import DeviceType, Device


@admin.register(DeviceType)
class DeviceTypeAdmin(admin.ModelAdmin):
    """
    Device Type Admin Interface
    Manages the types of devices that can be monitored (router, switch, etc.)
    """
    list_display = ('name', 'description')
    search_fields = ('name',)
    ordering = ('name',)


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    """
    Device Admin Interface
    Manages ISP devices being monitored including their status and configuration.
    """
    fieldsets = (
        ('Device Information', {
            'fields': ('name', 'device_type', 'ip_address', 'location')
        }),
        ('Organization & Assignment', {
            'fields': ('organisation', 'assigned_to')
        }),
        ('Monitoring Configuration', {
            'fields': ('snmp_community',)
        }),
        ('Status', {
            'fields': ('status', 'last_seen')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    readonly_fields = ('created_at', 'updated_at', 'last_seen')
    list_display = ('name', 'device_type', 'ip_address', 'organisation', 'status', 'assigned_to', 'last_seen')
    list_filter = ('status', 'device_type', 'organisation', 'created_at')
    search_fields = ('name', 'ip_address', 'location', 'organisation__name')
    ordering = ('organisation', 'name')
    autocomplete_fields = ('organisation',)

