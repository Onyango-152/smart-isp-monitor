from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model

from .serializers import (
    RegisterSerializer, LoginSerializer, UserProfileSerializer,
    ChangePasswordSerializer, UserListSerializer
)

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    """
    POST /api/users/register/

    Creates a new user and immediately returns JWT tokens plus the full
    user profile so the mobile client can navigate straight to the
    role-appropriate dashboard.
    """
    queryset           = User.objects.all()
    serializer_class   = RegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)
        return Response({
            'user':    UserProfileSerializer(user).data,
            'tokens':  {
                'refresh': str(refresh),
                'access':  str(refresh.access_token),
            },
            'message': 'Account created successfully.',
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    """
    POST /api/users/login/

    Accepts username OR email plus password.
    Returns JWT tokens and the full user profile.
    """
    permission_classes = [AllowAny]
    serializer_class   = LoginSerializer

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        identifier = serializer.validated_data['username']
        password   = serializer.validated_data['password']

        # Try username first, then email
        user = authenticate(username=identifier, password=password)
        if user is None:
            try:
                user_obj = User.objects.get(email=identifier)
                user     = authenticate(username=user_obj.username, password=password)
            except User.DoesNotExist:
                pass

        if user is None:
            return Response(
                {'error': 'Invalid credentials.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        refresh = RefreshToken.for_user(user)
        return Response({
            'user':   UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access':  str(refresh.access_token),
            },
        }, status=status.HTTP_200_OK)


class LogoutView(APIView):
    """
    User Logout View
    
    Invalidates refresh token (client-side handles access token removal).
    On mobile apps, this prevents token refresh requests.
    
    POST /api/users/logout/
    {
        "refresh": "token_here"
    }
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            refresh_token = request.data.get('refresh')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            return Response(
                {'message': 'Logged out successfully'},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )


class ProfileView(APIView):
    """
    User Profile View
    
    GET: Retrieve current authenticated user's profile
    PUT: Update current user's profile information
    
    GET /api/users/profile/
    PUT /api/users/profile/
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        """Return current user's profile"""
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data)
    
    def put(self, request):
        """Update current user's profile"""
        serializer = UserProfileSerializer(
            request.user,
            data=request.data,
            partial=True
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )


class ChangePasswordView(APIView):
    """
    Change Password View
    
    Allows authenticated users to change their password.
    Requires the old password for verification.
    
    POST /api/users/change-password/
    {
        "old_password": "current_password",
        "new_password": "new_password",
        "confirm_password": "new_password"
    }
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if serializer.is_valid():
            user = request.user
            
            # Verify old password
            if not user.check_password(serializer.validated_data['old_password']):
                return Response(
                    {'old_password': 'Wrong password'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Check new passwords match
            if serializer.validated_data['new_password'] != serializer.validated_data['confirm_password']:
                return Response(
                    {'new_password': 'Passwords do not match'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Update password
            user.set_password(serializer.validated_data['new_password'])
            user.save()
            
            return Response(
                {'message': 'Password changed successfully'},
                status=status.HTTP_200_OK
            )
        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )


class UserListView(generics.ListCreateAPIView):
    """
    User List View (Admin only)
    
    GET: List all users (admin only)
    POST: Create new user (admin only)
    
    GET /api/users/
    """
    queryset = User.objects.all().order_by('-date_joined')
    serializer_class = UserListSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        """Admin only - retrieve all users"""
        if not request.user.is_staff:
            return Response(
                {'error': 'Admin access required'},
                status=status.HTTP_403_FORBIDDEN
            )
        return super().get(request, *args, **kwargs)


class ClientListView(generics.ListAPIView):
    """
    GET /api/users/clients/
    Returns all users with role='customer'.
    Accessible to managers and admins only.
    """
    serializer_class   = UserListSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role not in ('manager', 'admin') and not user.is_staff:
            return User.objects.none()
        return User.objects.filter(role='customer').order_by('-date_joined')
