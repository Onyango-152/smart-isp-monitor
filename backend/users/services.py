import hashlib
import hmac
import secrets
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone


OTP_EXPIRY_MINUTES = 10
OTP_MAX_ATTEMPTS = 5
OTP_MAX_SENDS_PER_HOUR = 5


def _hash_otp(otp: str) -> str:
	payload = f"{otp}{settings.SECRET_KEY}".encode("utf-8")
	return hashlib.sha256(payload).hexdigest()


def _generate_otp() -> str:
	return f"{secrets.randbelow(1000000):06d}"


def can_resend_otp(user) -> bool:
	if not user.email_otp_sent_at:
		return True

	window_start = timezone.now() - timedelta(hours=1)
	if user.email_otp_sent_at < window_start:
		return True

	return user.email_otp_send_count < OTP_MAX_SENDS_PER_HOUR


def issue_email_otp(user) -> str:
	now = timezone.now()
	otp = _generate_otp()

	# Reset hourly send count if the window has passed
	if user.email_otp_sent_at and user.email_otp_sent_at < (now - timedelta(hours=1)):
		user.email_otp_send_count = 0
	
	user.email_otp_hash = _hash_otp(otp)
	user.email_otp_expires_at = now + timedelta(minutes=OTP_EXPIRY_MINUTES)
	user.email_otp_sent_at = now
	user.email_otp_send_count = (user.email_otp_send_count or 0) + 1
	user.email_otp_attempts = 0
	user.save(update_fields=[
		'email_otp_hash',
		'email_otp_expires_at',
		'email_otp_sent_at',
		'email_otp_send_count',
		'email_otp_attempts',
	])
	print(f"OTP issued: {otp} (hash: {user.email_otp_hash}, expires at: {user.email_otp_expires_at}, send count: {user.email_otp_send_count})")
	return otp


def send_verification_email(user, otp: str) -> None:
	subject = 'Verify your email address'
	message = (
		f"Hello {user.get_full_name() or user.username},\n\n"
		f"Your verification code is: {otp}\n\n"
		f"This code expires in {OTP_EXPIRY_MINUTES} minutes."
	)
	send_mail(
		subject=subject,
		message=message,
		from_email=settings.DEFAULT_FROM_EMAIL,
		recipient_list=[user.email],
		fail_silently=False,
	)


def verify_email_otp(user, otp: str) -> tuple[bool, str]:
	if user.email_verified:
		return True, 'Email already verified.'

	if not user.email_otp_hash or not user.email_otp_expires_at:
		return False, 'No verification code found. Please request a new one.'

	if user.email_otp_expires_at < timezone.now():
		return False, 'Verification code expired. Please request a new one.'

	if user.email_otp_attempts >= OTP_MAX_ATTEMPTS:
		return False, 'Too many attempts. Please request a new code.'

	expected = user.email_otp_hash
	provided = _hash_otp(otp)
	if not hmac.compare_digest(expected, provided):
		user.email_otp_attempts += 1
		user.save(update_fields=['email_otp_attempts'])
		return False, 'Invalid verification code.'

	user.email_verified = True
	user.email_otp_hash = None
	user.email_otp_expires_at = None
	user.email_otp_attempts = 0
	user.save(update_fields=[
		'email_verified',
		'email_otp_hash',
		'email_otp_expires_at',
		'email_otp_attempts',
	])

	return True, 'Email verified successfully.'


# ─────────────────────────────────────────────────────────────────────────
# Password Reset OTP Functions
# ─────────────────────────────────────────────────────────────────────────

def can_resend_password_reset_otp(user) -> bool:
	"""Check if user can request another password reset OTP."""
	if not user.password_reset_otp_sent_at:
		return True

	window_start = timezone.now() - timedelta(hours=1)
	if user.password_reset_otp_sent_at < window_start:
		return True

	return user.password_reset_otp_send_count < OTP_MAX_SENDS_PER_HOUR


def issue_password_reset_otp(user) -> str:
	"""Generate and store a password reset OTP for the user."""
	now = timezone.now()
	otp = _generate_otp()

	# Reset hourly send count if the window has passed
	if user.password_reset_otp_sent_at and user.password_reset_otp_sent_at < (now - timedelta(hours=1)):
		user.password_reset_otp_send_count = 0

	user.password_reset_otp_hash = _hash_otp(otp)
	user.password_reset_otp_expires_at = now + timedelta(minutes=OTP_EXPIRY_MINUTES)
	user.password_reset_otp_sent_at = now
	user.password_reset_otp_send_count = (user.password_reset_otp_send_count or 0) + 1
	user.password_reset_otp_attempts = 0
	user.save(update_fields=[
		'password_reset_otp_hash',
		'password_reset_otp_expires_at',
		'password_reset_otp_sent_at',
		'password_reset_otp_send_count',
		'password_reset_otp_attempts',
	])
	print(f"Password reset OTP issued: {otp} (hash: {user.password_reset_otp_hash})")
	return otp


def send_password_reset_email(user, otp: str) -> None:
	"""Send password reset email with OTP."""
	subject = 'Reset your password'
	message = (
		f"Hello {user.get_full_name() or user.username},\n\n"
		f"Your password reset code is: {otp}\n\n"
		f"This code expires in {OTP_EXPIRY_MINUTES} minutes.\n\n"
		f"If you did not request this, please ignore this email."
	)
	send_mail(
		subject=subject,
		message=message,
		from_email=settings.DEFAULT_FROM_EMAIL,
		recipient_list=[user.email],
		fail_silently=False,
	)


def verify_password_reset_otp(user, otp: str) -> tuple[bool, str]:
	"""Verify password reset OTP."""
	if not user.password_reset_otp_hash or not user.password_reset_otp_expires_at:
		return False, 'No password reset request found. Please request a new one.'

	if user.password_reset_otp_expires_at < timezone.now():
		user.password_reset_otp_hash = None
		user.password_reset_otp_expires_at = None
		user.save(update_fields=['password_reset_otp_hash', 'password_reset_otp_expires_at'])
		return False, 'Password reset code expired. Please request a new one.'

	if user.password_reset_otp_attempts >= OTP_MAX_ATTEMPTS:
		return False, 'Too many attempts. Please request a new code.'

	expected = user.password_reset_otp_hash
	provided = _hash_otp(otp)
	if not hmac.compare_digest(expected, provided):
		user.password_reset_otp_attempts += 1
		user.save(update_fields=['password_reset_otp_attempts'])
		return False, 'Invalid password reset code.'

	return True, 'Password reset code verified.'


def reset_password(user, otp: str, new_password: str) -> tuple[bool, str]:
	"""Reset user password after verifying OTP and new password."""
	# First verify the OTP
	is_valid, message = verify_password_reset_otp(user, otp)
	if not is_valid:
		return False, message

	# Set the new password and clear reset OTP fields
	user.set_password(new_password)
	user.password_reset_otp_hash = None
	user.password_reset_otp_expires_at = None
	user.password_reset_otp_attempts = 0
	user.save(update_fields=[
		'password',
		'password_reset_otp_hash',
		'password_reset_otp_expires_at',
		'password_reset_otp_attempts',
	])

	return True, 'Password reset successfully.'
