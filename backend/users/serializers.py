from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()

VALID_REGISTRATION_ROLES = {
    User.CUSTOMER,
    User.TECHNICIAN,
    User.MANAGER,
}


class RegisterSerializer(serializers.ModelSerializer):
    """
    Serializer for user registration.

    Accepts:
    - username        : login name (required, unique)
    - email           : email address (required, unique)
    - password        : min 8 chars (write-only)
    - password_confirm: must match password (write-only)
    - role            : customer | technician | manager  (required)
    - first_name      : optional
    - last_name       : optional
    - organization    : optional
    - phone           : optional
    """
    password         = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model  = User
        fields = (
            'username', 'email', 'password', 'password_confirm',
            'role', 'first_name', 'last_name', 'organization', 'phone',
        )
        extra_kwargs = {
            'email': {'required': True},
            'role':  {'required': True},
        }

    def validate_role(self, value):
        if value not in VALID_REGISTRATION_ROLES:
            raise serializers.ValidationError(
                f"Role must be one of: {', '.join(sorted(VALID_REGISTRATION_ROLES))}"
            )
        return value

    def validate(self, data):
        if data['password'] != data.pop('password_confirm'):
            raise serializers.ValidationError({'password': 'Passwords do not match.'})
        return data

    def create(self, validated_data):
        return User.objects.create_user(
            username     = validated_data['username'],
            email        = validated_data['email'],
            password     = validated_data['password'],
            role         = validated_data.get('role', User.CUSTOMER),
            first_name   = validated_data.get('first_name', ''),
            last_name    = validated_data.get('last_name', ''),
            organization = validated_data.get('organization', ''),
            phone        = validated_data.get('phone', ''),
        )


class LoginSerializer(serializers.Serializer):
    """
    Accepts username OR email plus password.
    """
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate_username(self, value):
        # Accept either username or email
        if (not User.objects.filter(username=value).exists() and
                not User.objects.filter(email=value).exists()):
            raise serializers.ValidationError(
                'No account found with this username or email.'
            )
        return value


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Full user profile returned after login / register / profile fetch.
    The `role` field drives routing on the mobile client.
    """
    full_name = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = (
            'id', 'username', 'email', 'first_name', 'last_name',
            'full_name', 'role', 'organization', 'phone',
            'email_verified',
            'is_active', 'is_staff', 'date_joined', 'last_login',
        )
        read_only_fields = (
            'id', 'username', 'is_active', 'is_staff',
            'date_joined', 'last_login',
        )

    def get_full_name(self, obj):
        return obj.get_full_name()


class ChangePasswordSerializer(serializers.Serializer):
    old_password     = serializers.CharField(write_only=True)
    new_password     = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True, min_length=8)


class UserListSerializer(serializers.ModelSerializer):
    """Admin user listing — shows the canonical role field."""
    full_name = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = (
            'id', 'username', 'email', 'full_name', 'role',
            'organization', 'phone', 'is_staff', 'is_active',
            'date_joined', 'last_login',
        )
        read_only_fields = ('id', 'date_joined', 'last_login')

    def get_full_name(self, obj):
        return obj.get_full_name()


class VerifyEmailSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp   = serializers.CharField(min_length=6, max_length=6)


class ResendOtpSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ForgotPasswordSerializer(serializers.Serializer):
    """Request password reset by email."""
    email = serializers.EmailField()


class VerifyPasswordResetOtpSerializer(serializers.Serializer):
    """Verify password reset OTP."""
    email = serializers.EmailField()
    otp   = serializers.CharField(min_length=6, max_length=6)


class ResetPasswordSerializer(serializers.Serializer):
    """Reset password with OTP and new password."""
    email           = serializers.EmailField()
    otp             = serializers.CharField(min_length=6, max_length=6)
    new_password    = serializers.CharField(min_length=8, write_only=True)
    confirm_password = serializers.CharField(min_length=8, write_only=True)

    def validate(self, data):
        if data['new_password'] != data['confirm_password']:
            raise serializers.ValidationError('Passwords do not match.')
        return data
