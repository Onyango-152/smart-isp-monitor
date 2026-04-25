from django.contrib import admin
from .models import AIConfiguration, Conversation, Message


class MessageInline(admin.TabularInline):
    model = Message
    extra = 0
    fields = ('role', 'content', 'timestamp', 'tokens_used')
    readonly_fields = ('timestamp',)
    can_delete = False


@admin.register(AIConfiguration)
class AIConfigurationAdmin(admin.ModelAdmin):
    list_display = ('name', 'provider', 'model_name', 'is_active', 'created_at')
    list_filter = ('provider', 'is_active')
    search_fields = ('name', 'model_name')
    fieldsets = (
        ('Basic Information', {
            'fields': ('name', 'provider', 'is_active')
        }),
        ('API Configuration', {
            'fields': ('api_key', 'model_name')
        }),
        ('Generation Settings', {
            'fields': ('max_tokens', 'temperature', 'system_prompt')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    readonly_fields = ('created_at', 'updated_at')


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'title', 'message_count', 'created_at', 'updated_at')
    list_filter = ('created_at', 'user')
    search_fields = ('title', 'user__username', 'user__email')
    readonly_fields = ('created_at', 'updated_at')
    inlines = [MessageInline]
    
    def message_count(self, obj):
        return obj.messages.count()
    message_count.short_description = 'Messages'


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('id', 'conversation', 'role', 'content_preview', 'timestamp')
    list_filter = ('role', 'timestamp')
    search_fields = ('content', 'conversation__title')
    readonly_fields = ('timestamp',)
    
    def content_preview(self, obj):
        return obj.content[:100] + '...' if len(obj.content) > 100 else obj.content
    content_preview.short_description = 'Content'
