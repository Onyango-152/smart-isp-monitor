from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    """
    Serializer for user registration.
    
    Accepts:
    - username: User's login name (required, unique)
    - email: User's email address (required, unique)
    - password: User's password (required, min 8 chars)
    - first_name: User's first name (optional)
    - last_name: User's last name (optional)
    - organization: Company/ISP name (optional)
    - phone: Contact phone number (optional)
    """
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = (
            'username', 'email', 'password', 'password_confirm',
            'first_name', 'last_name', 'organization', 'phone'
        )
        extra_kwargs = {
            'email': {'required': True},
        }

    def validate(self, data):
        """Ensure passwords match"""
        if data['password'] != data.pop('password_confirm'):
            raise serializers.ValidationError(
                {'password': 'Passwords do not match'}
            )
        return data

    def create(self, validated_data):
        """Create user with hashed password"""
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            organization=validated_data.get('organization', ''),
            phone=validated_data.get('phone', ''),
        )
        return user


class LoginSerializer(serializers.Serializer):
    """
    Serializer for user login.
    
    Accepts:
    - username: User's login name or email
    - password: User's password
    """
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate_username(self, value):
        """Validate that user exists"""
        if not User.objects.filter(username=value).exists():
            raise serializers.ValidationError(
                'User with this username does not exist'
            )
        return value


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for user profile information.
    
    Used for displaying user details and updating profile.
    Includes all user fields except password.
    """
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id', 'username', 'email', 'first_name', 'last_name',
            'full_name', 'organization', 'phone', 'is_technician',
            'is_sales', 'is_staff', 'date_joined', 'last_login'
        )
        read_only_fields = (
            'id', 'username', 'date_joined', 'last_login',
            'is_staff'  # Can only be set by admin
        )

    def get_full_name(self, obj):
        """Return user's full name"""
        return obj.get_full_name()


class ChangePasswordSerializer(serializers.Serializer):
    """
    Serializer for changing user password.
    
    Accepts:
    - old_password: Current password (for verification)
    - new_password: New password (min 8 chars)
    - confirm_password: Confirmation of new password (must match)
    """
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True, min_length=8)


class UserListSerializer(serializers.ModelSerializer):
    """
    Serializer for admin user listing.
    
    Shows all user information including staff/admin status.
    Used for admin panel user management.
    """
    full_name = serializers.SerializerMethodField()
    role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id', 'username', 'email', 'full_name', 'organization',
            'phone', 'is_technician', 'is_sales', 'is_staff',
            'is_active', 'role', 'date_joined', 'last_login'
        )
        read_only_fields = (
            'id', 'date_joined', 'last_login'
        )

    def get_full_name(self, obj):
        """Return user's full name"""
        return obj.get_full_name()

    def get_role(self, obj):
        """Determine user's role based on flags"""
        if obj.is_staff:
            return 'Admin'
        elif obj.is_technician:
            return 'Technician'
        elif obj.is_sales:
            return 'Sales'
        else:
            return 'User'
