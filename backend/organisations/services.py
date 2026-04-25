from datetime import timedelta
from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone

INVITATION_EXPIRY_DAYS = 7


def send_invitation_email(invitation, invited_by_user):
    """Send an email invitation to join an organisation."""
    org_name    = invitation.organisation.name
    inviter     = invited_by_user.get_full_name() or invited_by_user.username
    accept_url  = f"{getattr(settings, 'FRONTEND_URL', 'http://localhost:8000')}/invitations/{invitation.token}/accept/"
    decline_url = f"{getattr(settings, 'FRONTEND_URL', 'http://localhost:8000')}/invitations/{invitation.token}/decline/"

    subject = f"You've been invited to join {org_name} on ISP Monitor"
    message = (
        f"Hello,\n\n"
        f"{inviter} has invited you to join {org_name} as a {invitation.role}.\n\n"
        f"Accept:  {accept_url}\n"
        f"Decline: {decline_url}\n\n"
        f"This invitation expires in {INVITATION_EXPIRY_DAYS} days.\n\n"
        f"If you don't have an account yet, register first then use the link above."
    )
    send_mail(
        subject=subject,
        message=message,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[invitation.email],
        fail_silently=False,
    )


def create_invitation(organisation, invited_by, email, role):
    from .models import Invitation
    # Cancel any existing pending invite for same email+org
    Invitation.objects.filter(
        organisation=organisation,
        email=email,
        status='pending',
    ).update(status='cancelled')

    return Invitation.objects.create(
        organisation=organisation,
        invited_by=invited_by,
        email=email,
        role=role,
        expires_at=timezone.now() + timedelta(days=INVITATION_EXPIRY_DAYS),
    )
