from django.contrib import admin
from .models import Organisation, Membership, Invitation


class MembershipInline(admin.TabularInline):
    model           = Membership
    extra           = 0
    fields          = ('user', 'role', 'invited_by', 'joined_at')
    readonly_fields = ('joined_at',)


class InvitationInline(admin.TabularInline):
    model           = Invitation
    extra           = 0
    fields          = ('email', 'role', 'status', 'expires_at', 'created_at')
    readonly_fields = ('token', 'created_at')


class DeviceInline(admin.TabularInline):
    from devices.models import Device
    model           = Device
    extra           = 0
    fields          = ('name', 'device_type', 'ip_address', 'status', 'last_seen')
    readonly_fields = ('last_seen',)
    can_delete      = False


@admin.register(Organisation)
class OrganisationAdmin(admin.ModelAdmin):
    list_display        = ('name', 'slug', 'created_by', 'member_count', 'device_count', 'is_active', 'created_at')
    list_filter         = ('is_active',)
    search_fields       = ('name', 'slug')
    prepopulated_fields = {'slug': ('name',)}
    inlines             = [MembershipInline, DeviceInline, InvitationInline]
    
    def member_count(self, obj):
        return obj.memberships.count()
    member_count.short_description = 'Members'
    
    def device_count(self, obj):
        return obj.devices.count()
    device_count.short_description = 'Devices'


@admin.register(Membership)
class MembershipAdmin(admin.ModelAdmin):
    list_display  = ('user', 'organisation', 'role', 'invited_by', 'joined_at')
    list_filter   = ('role', 'organisation')
    search_fields = ('user__username', 'user__email', 'organisation__name')


@admin.register(Invitation)
class InvitationAdmin(admin.ModelAdmin):
    list_display  = ('email', 'organisation', 'role', 'status', 'invited_by', 'created_at', 'expires_at')
    list_filter   = ('status', 'role', 'organisation')
    search_fields = ('email', 'organisation__name')
    readonly_fields = ('token',)
