from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0003_email_verification'),
    ]

    operations = [
        migrations.AddField(
            model_name='customuser',
            name='password_reset_otp_hash',
            field=models.CharField(blank=True, max_length=128, null=True),
        ),
        migrations.AddField(
            model_name='customuser',
            name='password_reset_otp_expires_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='customuser',
            name='password_reset_otp_sent_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='customuser',
            name='password_reset_otp_send_count',
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name='customuser',
            name='password_reset_otp_attempts',
            field=models.IntegerField(default=0),
        ),
    ]
