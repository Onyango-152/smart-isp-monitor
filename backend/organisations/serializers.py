from rest_framework import serializers
from django.utils.text import slugify
from .models import Organisation, Membership, Invitation
from django.contrib.auth import get_user_model

User = get_user_model()


class MembershipSerializer(serializers.ModelSerializer):
    username  = serializers.CharField(source='user.username',       read_only=True)
    email     = serializers.CharField(source='user.email',          read_only=True)
    full_name = serializers.CharField(source='user.get_full_name',  read_only=True)

    class Meta:
        model  = Membership
        fields = ['id', 'user', 'username', 'email', 'full_name', 'role', 'joined_at']
        read_only_fields = ['joined_at']


class OrganisationSerializer(serializers.ModelSerializer):
    members_count       = serializers.SerializerMethodField()
    created_by_username = serializers.CharField(source='created_by.username', read_only=True)

    class Meta:
        model  = Organisation
        fields = [
            'id', 'name', 'slug', 'description',
            'created_by', 'created_by_username',
            'is_active', 'members_count', 'created_at',
        ]
        read_only_fields = ['slug', 'created_by', 'created_at']

    def get_members_count(self, obj):
        return obj.memberships.count()

    def create(self, validated_data):
        validated_data['slug']       = slugify(validated_data['name'])
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class AddMemberSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()
    role    = serializers.ChoiceField(choices=['technician', 'customer', 'manager'])

    def validate_user_id(self, value):
        if not User.objects.filter(pk=value).exists():
            raise serializers.ValidationError('User not found.')
        return value


class InvitationSerializer(serializers.ModelSerializer):
    invited_by_username = serializers.CharField(source='invited_by.username', read_only=True)
    org_name            = serializers.CharField(source='organisation.name',   read_only=True)
    is_expired          = serializers.BooleanField(read_only=True)

    class Meta:
        model  = Invitation
        fields = [
            'id', 'organisation', 'org_name',
            'invited_by', 'invited_by_username',
            'email', 'role', 'status', 'is_expired',
            'created_at', 'expires_at', 'responded_at',
        ]
        read_only_fields = [
            'invited_by', 'status', 'created_at',
            'expires_at', 'responded_at', 'token',
        ]


class SendInvitationSerializer(serializers.Serializer):
    email = serializers.EmailField()
    role  = serializers.ChoiceField(choices=['technician', 'customer', 'manager'])


class BulkInviteSerializer(serializers.Serializer):
    emails = serializers.ListField(
        child=serializers.EmailField(),
        min_length=1,
        max_length=50,
    )
    role = serializers.ChoiceField(choices=['technician', 'customer', 'manager'])
