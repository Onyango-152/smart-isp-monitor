from django.apps import AppConfig


class MonitoringConfig(AppConfig):
    name = 'monitoring'

    def ready(self):
        # Start the background SNMP polling + alert evaluation scheduler.
        # Guard against double-start in Django's dev-server autoreload process.
        import os
        if os.environ.get('RUN_MAIN') != 'true':
            return
        try:
            from utils.scheduler import start
            start()
        except Exception as exc:
            import logging
            logging.getLogger(__name__).warning(
                'Could not start monitoring scheduler: %s', exc
            )
