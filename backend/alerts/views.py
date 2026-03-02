from django.shortcuts import render

# Create your views here.



class RegisterView(generics.CreateAPIView):
    """
    POST /api/users/register/

    Allows a new user to create an account.
    permission_classes = [AllowAny] overrides the global setting in
    settings.py that requires authentication for all endpoints.
    This endpoint must be public — you cannot require a token to register
    because the user does not have a token yet.
    """
    queryset            = User.objects.all()
    serializer_class    = RegisterSerializer
    permission_classes  = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)

        # is_valid() runs all the validation rules in the serializer.
        # raise_exception=True means if validation fails it automatically
        # returns a 400 Bad Request response with the error details.
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        # After creating the user we immediately generate a JWT token
        # so the app can log the user in right after registration
        # without requiring a separate login request.
        refresh = RefreshToken.for_user(user)

        return Response({
            'message':       'Account created successfully.',
            'user':          UserSerializer(user).data,
            'access_token':  str(refresh.access_token),
            'refresh_token': str(refresh),
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    """
    POST /api/users/login/

    Accepts email and password, returns JWT tokens if credentials are valid.
    This is the endpoint the Flutter login screen will call first.
    The response includes both an access token (short-lived, used for
    all API requests) and a refresh token (long-lived, used to silently
    get a new access token when the current one expires).
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email    = request.data.get('email')
        password = request.data.get('password')

        # Validate that both fields were provided
        if not email or not password:
            return Response(
                {'error': 'Please provide both email and password.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # authenticate() checks the credentials against the database.
        # It returns the User object if valid, or None if invalid.
        # We pass email as the username because our custom User model
        # uses email as the USERNAME_FIELD.
        user = authenticate(request, username=email, password=password)

        if not user:
            return Response(
                {'error': 'Invalid email or password.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.is_active:
            return Response(
                {'error': 'This account has been deactivated.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Update last_login timestamp
        user.last_login = timezone.now()
        user.save(update_fields=['last_login'])

        # Generate fresh JWT tokens for this user
        refresh = RefreshToken.for_user(user)

        return Response({
            'message':       'Login successful.',
            'user':          UserSerializer(user).data,
            'access_token':  str(refresh.access_token),
            'refresh_token': str(refresh),
        }, status=status.HTTP_200_OK)


class LogoutView(APIView):
    """
    POST /api/users/logout/

    Blacklists the refresh token so it cannot be used to generate
    new access tokens. The access token will still technically be valid
    until it expires (12 hours) but with no refresh token the user
    will be forced to log in again after that.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get('refresh_token')
            token = RefreshToken(refresh_token)

            # blacklist() invalidates this specific refresh token
            # so it can never be used again even if someone steals it.
            token.blacklist()

            return Response(
                {'message': 'Logged out successfully.'},
                status=status.HTTP_200_OK,
            )
        except Exception:
            return Response(
                {'error': 'Invalid token.'},
                status=status.HTTP_400_BAD_REQUEST,
            )


class ProfileView(APIView):
    """
    GET  /api/users/profile/  — returns the current user's profile
    PUT  /api/users/profile/  — updates the current user's profile

    request.user is automatically populated by the JWT authentication
    middleware. By the time this view runs Django has already validated
    the token and attached the corresponding User object to the request.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    def put(self, request):
        serializer = UpdateProfileSerializer(
            request.user,
            data=request.data,
            partial=True,  # partial=True allows updating only some fields
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({
            'message': 'Profile updated successfully.',
            'user':    UserSerializer(request.user).data,
        })


class ChangePasswordView(APIView):
    """
    POST /api/users/change-password/

    Allows a logged-in user to change their own password.
    Requires the current password to prevent unauthorised changes
    if someone gets temporary access to an unlocked phone.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Verify the old password is correct before allowing the change
        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response(
                {'error': 'Current password is incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # set_password() hashes the new password before saving it.
        # Never save a plain text password with user.password = '...'
        user.set_password(serializer.validated_data['new_password'])
        user.save()

        return Response(
            {'message': 'Password changed successfully. Please log in again.'},
            status=status.HTTP_200_OK,
        )


class UserListView(generics.ListAPIView):
    """
    GET /api/users/

    Returns a list of all users. Only accessible by admin users.
    Used by the admin dashboard to manage user accounts.
    """
    queryset           = User.objects.all().order_by('email')
    serializer_class   = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """
        Override get_queryset to restrict access to admin users only.
        If a non-admin tries to access this endpoint they get a 403.
        """
        if self.request.user.role != 'admin':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied(
                'Only admin users can view the full user list.'
            )
        return User.objects.all().order_by('email')