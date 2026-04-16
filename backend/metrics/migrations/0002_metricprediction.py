from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('devices', '0002_initial'),
        ('metrics', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='MetricPrediction',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('predicted_value', models.FloatField()),
                ('slope_per_min', models.FloatField()),
                ('risk_level', models.CharField(choices=[('low', 'Low'), ('medium', 'Medium'), ('high', 'High'), ('critical', 'Critical')], max_length=20)),
                ('horizon_minutes', models.PositiveIntegerField(default=60)),
                ('generated_at', models.DateTimeField(auto_now=True)),
                ('device', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='metric_predictions', to='devices.device')),
                ('metric', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='metrics.metric')),
            ],
            options={
                'verbose_name': 'Metric Prediction',
                'verbose_name_plural': 'Metric Predictions',
                'ordering': ['-generated_at'],
                'unique_together': {('device', 'metric')},
            },
        ),
    ]
