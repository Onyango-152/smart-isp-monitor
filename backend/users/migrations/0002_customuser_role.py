from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0001_initial'),
    ]

    operations = [
        # Add the new canonical role field
        migrations.AddField(
            model_name='customuser',
            name='role',
            field=models.CharField(
                choices=[
                    ('customer',   'Customer'),
                    ('technician', 'Technician'),
                    ('manager',    'Manager'),
                    ('admin',      'Admin'),
                ],
                default='customer',
                db_index=True,
                max_length=20,
            ),
        ),
        # Remove the now-redundant boolean flags that were in 0001_initial
        migrations.RemoveField(
            model_name='customuser',
            name='is_technician',
        ),
        migrations.RemoveField(
            model_name='customuser',
            name='is_sales',
        ),
    ]
