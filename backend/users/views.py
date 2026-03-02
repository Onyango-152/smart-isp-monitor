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
    User Registration View
    
    Allows new users to create an account with email and password.
    Returns JWT tokens (access and refresh) upon successful registration.
    
    POST /api/users/register/
    """
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]
    
    def perform_create(self, serializer):
        """Override to set password hash before saving"""
        user = serializer.save()
        user.set_password(serializer.validated_data['password'])
        user.save()
    
    def create(self, request, *args, **kwargs):
        """Override to return tokens on successful registration"""
        response = super().create(request, *args, **kwargs)
        user = User.objects.get(username=response.data['username'])
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        response.data['tokens'] = {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }
        response.data['message'] = 'User registered successfully'
        return response


class LoginView(APIView):
    """
    User Login View
    
    Authenticates user with username and password, returns JWT tokens.
    
    POST /api/users/login/
    {
        "username": "user@example.com",
        "password": "password123"
    }
    """
    permission_classes = [AllowAny]
    serializer_class = LoginSerializer
    
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            username = serializer.validated_data['username']
            password = serializer.validated_data['password']
            
            user = authenticate(username=username, password=password)
            if user:
                refresh = RefreshToken.for_user(user)
                return Response({
                    'user': UserProfileSerializer(user).data,
                    'tokens': {
                        'refresh': str(refresh),
                        'access': str(refresh.access_token),
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response(
                    {'error': 'Invalid credentials'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


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

