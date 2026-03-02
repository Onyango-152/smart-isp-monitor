from rest_framework import serializers
from .models import AlertRule, Alert, NotificationChannel


# Serializers for alert management will be added here


    """
    Handles new user registration.
    The Flutter app sends email, username, password, and role.
    This serializer validates the data and creates the user.
    We use write_only=True on password fields so they are accepted
    on input but never included in any response sent back — you
    never want to return a password in an API response even if hashed.
    """

    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],  # runs Django's built-in password rules
    )
    password2 = serializers.CharField(
        write_only=True,
        required=True,
        label='Confirm Password',
    )

    class Meta:
        model  = User
        fields = ('id', 'email', 'username', 'password', 'password2', 'role')
        extra_kwargs = {
            'role': {'required': False},  # role is optional, defaults to technician
        }

    def validate(self, attrs):
        """
        validate() is called after all individual field validations pass.
        Here we check that the two passwords match.
        attrs is a dictionary of all the validated field values.
        """
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError(
                {'password': 'Password fields do not match.'}
            )
        return attrs

    def create(self, validated_data):
        """
        create() is called when serializer.save() is called in the view.
        We remove password2 since we only need one password to create the user.
        We use create_user() instead of create() because create_user()
        automatically hashes the password before saving it to the database.
        Never store plain text passwords.
        """
        validated_data.pop('password2')
        user = User.objects.create_user(
            email    = validated_data['email'],
            username = validated_data['username'],
            password = validated_data['password'],
            role     = validated_data.get('role', UserRole.TECHNICIAN),
        )
        return user


class UserSerializer(serializers.ModelSerializer):
    """
    Used for returning user profile data in API responses.
    This is a read-only serializer — it only converts User objects
    to JSON, it does not handle creating or updating users.
    """

    class Meta:
        model  = User
        fields = ('id', 'email', 'username', 'role', 'is_active',
                  'date_joined', 'last_login')
        # read_only_fields means these fields can never be changed
        # through this serializer even if someone sends them in a request.
        read_only_fields = ('id', 'date_joined', 'last_login')


class UpdateProfileSerializer(serializers.ModelSerializer):
    """
    Allows a logged-in user to update their own profile details.
    They can change their username and FCM token but not their
    email, role, or password through this serializer.
    """

    class Meta:
        model  = User
        fields = ('username', 'fcm_token')


class ChangePasswordSerializer(serializers.Serializer):
    """
    Handles password change requests.
    The user must provide their current password to prove identity,
    then provide the new password twice for confirmation.
    Note: We inherit from plain Serializer not ModelSerializer here
    because this operation does not map directly to model fields.
    """

    old_password = serializers.CharField(write_only=True, required=True)
    new_password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
    )
    new_password2 = serializers.CharField(write_only=True, required=True)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password2']:
            raise serializers.ValidationError(
                {'new_password': 'New password fields do not match.'}
            )
        return attrs