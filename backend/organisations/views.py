from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone

from .models import Organisation, Membership, Invitation
from .serializers import (
    OrganisationSerializer, MembershipSerializer,
    AddMemberSerializer, InvitationSerializer,
    SendInvitationSerializer, BulkInviteSerializer,
)
from .services import create_invitation, send_invitation_email
from django.contrib.auth import get_user_model

User = get_user_model()


def _user_orgs(user):
    """Return orgs the user is a member of (or owns as manager/admin)."""
    if user.role == 'admin':
        return Organisation.objects.filter(is_active=True)
    return Organisation.objects.filter(
        memberships__user=user, is_active=True
    ).distinct()


class OrganisationListView(generics.ListCreateAPIView):
    """
    GET  /api/organisations/        — list orgs the current user belongs to
    POST /api/organisations/        — create a new org (manager/admin only)
    """
    serializer_class   = OrganisationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return _user_orgs(self.request.user)

    def create(self, request, *args, **kwargs):
        if request.user.role not in ('manager', 'admin'):
            return Response(
                {'error': 'Only managers or admins can create organisations.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        org = serializer.save()
        # Auto-add creator as manager member
        Membership.objects.create(
            organisation=org,
            user=request.user,
            role='manager',
            invited_by=request.user,
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class OrganisationDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET / PUT / DELETE /api/organisations/<pk>/
    Only members can retrieve; only managers/admins can modify.
    """
    serializer_class   = OrganisationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return _user_orgs(self.request.user)

    def update(self, request, *args, **kwargs):
        org = self.get_object()
        if not _is_org_manager(request.user, org):
            return Response({'error': 'Only org managers can edit this.'}, status=403)
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        org = self.get_object()
        if not _is_org_manager(request.user, org):
            return Response({'error': 'Only org managers can delete this.'}, status=403)
        return super().destroy(request, *args, **kwargs)


class MemberListView(generics.ListAPIView):
    """
    GET /api/organisations/<org_pk>/members/
    Lists all members of an organisation.
    """
    serializer_class   = MembershipSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        org = _get_member_org(self.request.user, self.kwargs['org_pk'])
        if org is None:
            return Membership.objects.none()
        return org.memberships.select_related('user').all()


class AddMemberView(APIView):
    """
    POST /api/organisations/<org_pk>/members/add/
    Manager adds a user to the organisation.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, org_pk):
        org = _get_member_org(request.user, org_pk)
        if org is None:
            return Response({'error': 'Organisation not found.'}, status=404)
        if not _is_org_manager(request.user, org):
            return Response({'error': 'Only org managers can add members.'}, status=403)

        serializer = AddMemberSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = User.objects.get(pk=serializer.validated_data['user_id'])
        role = serializer.validated_data['role']

        membership, created = Membership.objects.get_or_create(
            organisation=org,
            user=user,
            defaults={'role': role, 'invited_by': request.user},
        )
        if not created:
            membership.role = role
            membership.save()

        return Response(MembershipSerializer(membership).data,
                        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class RemoveMemberView(APIView):
    """
    DELETE /api/organisations/<org_pk>/members/<user_pk>/
    Manager removes a user from the organisation.
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request, org_pk, user_pk):
        org = _get_member_org(request.user, org_pk)
        if org is None:
            return Response({'error': 'Organisation not found.'}, status=404)
        if not _is_org_manager(request.user, org):
            return Response({'error': 'Only org managers can remove members.'}, status=403)

        deleted, _ = Membership.objects.filter(
            organisation=org, user_id=user_pk
        ).delete()
        if not deleted:
            return Response({'error': 'Membership not found.'}, status=404)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MyOrganisationsView(generics.ListAPIView):
    """
    GET /api/organisations/mine/
    Returns all orgs the current user is a member of, with their role.
    """
    serializer_class   = OrganisationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return _user_orgs(self.request.user)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_member_org(user, org_pk):
    """Return org if user is a member (or admin), else None."""
    try:
        if user.role == 'admin':
            return Organisation.objects.get(pk=org_pk, is_active=True)
        return Organisation.objects.get(
            pk=org_pk,
            is_active=True,
            memberships__user=user,
        )
    except Organisation.DoesNotExist:
        return None


def _is_org_manager(user, org):
    """True if user is admin or has manager role in this org."""
    if user.role == 'admin':
        return True
    return Membership.objects.filter(
        organisation=org, user=user, role='manager'
    ).exists()


# ── Invitation views ──────────────────────────────────────────────────────────

class BulkInviteView(APIView):
    """
    POST /api/organisations/<org_pk>/invitations/bulk/
    Send invitations to multiple emails at once, all with the same role.

    Request body:
        { "emails": ["a@x.com", "b@x.com"], "role": "technician" }

    Response:
        {
          "sent":    ["a@x.com"],
          "skipped": [{"email": "b@x.com", "reason": "Already a member"}],
          "failed":  [{"email": "c@x.com", "reason": "Email send failed"}]
        }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, org_pk):
        org = _get_member_org(request.user, org_pk)
        if org is None:
            return Response({'error': 'Organisation not found.'}, status=404)
        if not _is_org_manager(request.user, org):
            return Response({'error': 'Only org managers can send invitations.'}, status=403)

        serializer = BulkInviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        emails = list(dict.fromkeys(  # deduplicate preserving order
            e.lower().strip() for e in serializer.validated_data['emails']
        ))
        role = serializer.validated_data['role']

        sent    = []
        skipped = []
        failed  = []

        # Pre-fetch existing members' emails for fast lookup
        member_emails = set(
            org.memberships.select_related('user')
            .values_list('user__email', flat=True)
        )

        for email in emails:
            # Already a member?
            if email in member_emails:
                skipped.append({'email': email, 'reason': 'Already a member'})
                continue

            try:
                invitation = create_invitation(org, request.user, email, role)
                send_invitation_email(invitation, request.user)
                sent.append(email)
            except Exception as exc:
                failed.append({'email': email, 'reason': str(exc)})

        return Response({
            'sent':    sent,
            'skipped': skipped,
            'failed':  failed,
        }, status=status.HTTP_200_OK)


class SendInvitationView(APIView):
    """
    POST /api/organisations/<org_pk>/invitations/
    Manager sends an email invitation to a user by email address.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, org_pk):
        org = _get_member_org(request.user, org_pk)
        if org is None:
            return Response({'error': 'Organisation not found.'}, status=404)
        if not _is_org_manager(request.user, org):
            return Response({'error': 'Only org managers can send invitations.'}, status=403)

        serializer = SendInvitationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data['email']
        role  = serializer.validated_data['role']

        # If user already a member, reject
        invited_user = User.objects.filter(email=email).first()
        if invited_user and Membership.objects.filter(organisation=org, user=invited_user).exists():
            return Response({'error': 'This user is already a member.'}, status=400)

        invitation = create_invitation(org, request.user, email, role)
        try:
            send_invitation_email(invitation, request.user)
            email_sent = True
        except Exception:
            email_sent = False

        return Response({
            'invitation': InvitationSerializer(invitation).data,
            'email_sent': email_sent,
        }, status=status.HTTP_201_CREATED)


class InvitationListView(generics.ListAPIView):
    """
    GET /api/organisations/<org_pk>/invitations/
    Lists all invitations for an org (manager only).
    """
    serializer_class   = InvitationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        org = _get_member_org(self.request.user, self.kwargs['org_pk'])
        if org is None or not _is_org_manager(self.request.user, org):
            return Invitation.objects.none()
        return org.invitations.order_by('-created_at')


class CancelInvitationView(APIView):
    """
    DELETE /api/organisations/<org_pk>/invitations/<inv_pk>/
    Manager cancels a pending invitation.
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request, org_pk, inv_pk):
        org = _get_member_org(request.user, org_pk)
        if org is None:
            return Response({'error': 'Organisation not found.'}, status=404)
        if not _is_org_manager(request.user, org):
            return Response({'error': 'Only org managers can cancel invitations.'}, status=403)

        try:
            inv = Invitation.objects.get(pk=inv_pk, organisation=org)
        except Invitation.DoesNotExist:
            return Response({'error': 'Invitation not found.'}, status=404)

        if inv.status != 'pending':
            return Response({'error': f'Cannot cancel a {inv.status} invitation.'}, status=400)

        inv.status = 'cancelled'
        inv.save(update_fields=['status'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class AcceptInvitationView(APIView):
    """
    POST /api/invitations/<pk>/accept/       — in-app (authenticated, by id)
    POST /api/invitations/<token>/accept/    — email link (by token string)
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk=None, token=None):
        try:
            if pk is not None:
                inv = Invitation.objects.select_related('organisation').get(pk=pk)
            else:
                inv = Invitation.objects.select_related('organisation').get(token=token)
        except Invitation.DoesNotExist:
            return Response({'error': 'Invalid invitation.'}, status=404)

        if inv.email.lower() != request.user.email.lower():
            return Response({'error': 'This invitation was sent to a different email address.'}, status=403)

        if inv.status != 'pending':
            return Response({'error': f'This invitation has already been {inv.status}.'}, status=400)

        if inv.is_expired:
            inv.status = 'expired'
            inv.save(update_fields=['status'])
            return Response({'error': 'This invitation has expired.'}, status=400)

        membership, _ = Membership.objects.get_or_create(
            organisation=inv.organisation,
            user=request.user,
            defaults={'role': inv.role, 'invited_by': inv.invited_by},
        )

        inv.status       = 'accepted'
        inv.responded_at = timezone.now()
        inv.save(update_fields=['status', 'responded_at'])

        return Response({
            'message':      f'You have joined {inv.organisation.name}.',
            'organisation': OrganisationSerializer(inv.organisation, context={'request': request}).data,
            'membership':   MembershipSerializer(membership).data,
        })


class DeclineInvitationView(APIView):
    """
    POST /api/invitations/<pk>/decline/      — in-app (authenticated, by id)
    POST /api/invitations/<token>/decline/   — email link (by token string)
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk=None, token=None):
        try:
            if pk is not None:
                inv = Invitation.objects.get(pk=pk)
            else:
                inv = Invitation.objects.get(token=token)
        except Invitation.DoesNotExist:
            return Response({'error': 'Invalid invitation.'}, status=404)

        if inv.email.lower() != request.user.email.lower():
            return Response({'error': 'This invitation was sent to a different email address.'}, status=403)

        if inv.status != 'pending':
            return Response({'error': f'This invitation has already been {inv.status}.'}, status=400)

        inv.status       = 'declined'
        inv.responded_at = timezone.now()
        inv.save(update_fields=['status', 'responded_at'])

        return Response({'message': 'Invitation declined.'})


class MyInvitationsView(generics.ListAPIView):
    """
    GET /api/invitations/
    Returns all pending invitations for the logged-in user's email.
    """
    serializer_class   = InvitationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Invitation.objects.filter(
            email=self.request.user.email,
            status='pending',
        ).order_by('-created_at')
