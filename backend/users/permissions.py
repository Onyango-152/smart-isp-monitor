from rest_framework.permissions import BasePermission


class IsAdmin(BasePermission):
    """
    Allows access only to users with the admin role.
    We will use this to protect user management endpoints.
    """

    message = 'Access restricted to admin users only.'

    def has_permission(self, request, view):
        # request.user is the authenticated user attached to the request
        # by the JWT middleware. We check their role field.
        return (
            request.user and
            request.user.is_authenticated and
            request.user.role == 'admin'
        )


class IsManager(BasePermission):
    """
    Allows access to managers and admins.
    Admins always have at least manager-level access.
    We will use this to protect the reports and analytics endpoints.
    """

    message = 'Access restricted to manager users only.'

    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            request.user.role in ('manager', 'admin')
        )


class IsTechnician(BasePermission):
    """
    Allows access to technicians, managers, and admins.
    We will use this for device management and alert endpoints
    since all three roles need access to those features.
    """

    message = 'Access restricted to technician users only.'

    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            request.user.role in ('technician', 'manager', 'admin')
        )


class IsCustomer(BasePermission):
    """
    Allows access to customers only.
    We will use this for the customer portal endpoints that show
    a simplified view of service status.
    """

    message = 'Access restricted to customer users only.'

    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            request.user.role == 'customer'
        )


class IsOwnerOrAdmin(BasePermission):
    """
    Object-level permission. Allows a user to access only their own
    data unless they are an admin. For example a customer should only
    be able to see their own profile, not other users' profiles.

    has_object_permission() is called on individual object retrieval,
    update, or delete — not on list views.
    The obj parameter is the specific database record being accessed.
    """

    message = 'You can only access your own data.'

    def has_object_permission(self, request, view, obj):
        return (
            request.user and
            request.user.is_authenticated and
            (obj == request.user or request.user.role == 'admin')
        )