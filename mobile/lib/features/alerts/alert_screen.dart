import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/alert_model.dart';

class AlertScreen extends StatelessWidget {
  final List<AlertModel> alerts;

  const AlertScreen({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerts'),
      ),
      body: alerts.isEmpty
          ? Center(
              child: Text(
                'No alerts found.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final severityColor = AppUtils.severityColor(alert.severity);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.warning_amber, color: severityColor),
                    title: Text(alert.message,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${alert.alertType}'),
                        Text('Severity: ${alert.severity}'),
                        Text('Triggered: ${AppUtils.timeAgo(alert.triggeredAt)}'),
                      ],
                    ),
                    trailing: alert.isAcknowledged
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ACK', style: TextStyle(color: AppColors.primary)),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
