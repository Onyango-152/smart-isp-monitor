import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../../services/diagnostic_service.dart';

/// DiagnosticScreen runs comprehensive diagnostics on a device
/// and provides detailed results and remediation steps.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  late DiagnosticResult _diagnosticResult;
  bool _isRunning = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start the diagnostic automatically when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDiagnostic();
    });
  }

  Future<void> _runDiagnostic() async {
    try {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      debugPrint('DiagnosticScreen received arguments: '
          '${arguments.runtimeType} $arguments');

      if (arguments == null || arguments is! DeviceModel) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final device = arguments;
      final result = await DiagnosticService.runDiagnostics(device);

      if (!mounted) return;

      setState(() {
        _diagnosticResult = result;
        _isRunning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Diagnostic failed: $e';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final device =
        ModalRoute.of(context)?.settings.arguments as DeviceModel?;

    if (_isRunning) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Running comprehensive diagnostics...'),
              const SizedBox(height: 8),
              Text(
                'Device: ${device?.name}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.offline),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Results'),
        actions: [
          TextButton(
            onPressed: _runDiagnostic,
            child: const Text(
              'Run Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Device Info  ──────────────────────────────────────────
            _buildDeviceCard(device),
            const SizedBox(height: 16),

            // ── Overall Result ────────────────────────────────────────
            _buildOverallResultCard(),
            const SizedBox(height: 16),

            // ── Diagnostic Checks ─────────────────────────────────────
            _buildDiagnosticChecks(),
            const SizedBox(height: 16),

            // ── Recommendations ──────────────────────────────────────
            _buildRecommendations(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel? device) {
    if (device == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryDarkSurface : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              AppUtils.deviceTypeIcon(device.deviceType),
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  '${AppUtils.deviceTypeLabel(device.deviceType)} • ${device.ipAddress}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallResultCard() {
    final cs = Theme.of(context).colorScheme;
    final passedCount =
        _diagnosticResult.checks.where((c) => c.passed).length;
    final totalCount = _diagnosticResult.checks.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            _diagnosticResult.isHealthy ? AppColors.onlineLight : AppColors.offlineLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _diagnosticResult.isHealthy ? AppColors.online : AppColors.offline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _diagnosticResult.isHealthy
                ? Icons.check_circle_outline
                : Icons.warning_amber,
            color: _diagnosticResult.isHealthy ? AppColors.online : AppColors.offline,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _diagnosticResult.isHealthy ? 'All Systems Healthy' : 'Issues Detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _diagnosticResult.isHealthy
                        ? AppColors.online
                        : AppColors.offline,
                  ),
                ),
                Text(
                  '$passedCount of $totalCount checks passed',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticChecks() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diagnostic Checks',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ..._diagnosticResult.checks.map((check) {
          return _buildCheckItem(check);
        }),
      ],
    );
  }

  Widget _buildCheckItem(DiagnosticCheck check) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = check.passed
        ? (isDark ? AppColors.onlineDark : AppColors.onlineLight)
        : (isDark ? AppColors.offlineDark : AppColors.offlineLight);
    final borderColor = check.passed ? AppColors.online : AppColors.offline;
    final icon = check.passed ? Icons.check_circle_outline : Icons.cancel_outlined;
    final iconColor = check.passed ? AppColors.online : AppColors.offline;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  check.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                check.passed ? 'PASS' : 'FAIL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            check.message,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withOpacity(0.65),
            ),
          ),
          if (check.details != null) ...[
            const SizedBox(height: 8),
            _buildDetailsTable(check.details!),
          ],
          if (check.remediation != null && !check.passed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended Action:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    check.remediation!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsTable(Map<String, dynamic> details) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: details.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.65),
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendations() {
    final cs = Theme.of(context).colorScheme;
    final failedChecks =
        _diagnosticResult.checks.where((c) => !c.passed).toList();

    if (failedChecks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.onlineLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.online.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.online),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Issues Found',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.online,
                    ),
                  ),
                  const Text(
                    'Device is operating normally',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...failedChecks.map((check) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  check.remediation ??
                      'Contact your system administrator for assistance.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.65),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to troubleshoot screen
                      final device = ModalRoute.of(context)?.settings.arguments
                          as DeviceModel?;
                      if (device != null) {
                        Navigator.of(context).pushNamed(
                          AppConstants.troubleshootRoute,
                          arguments: device,
                        );
                      }
                    },
                    child: const Text('Get Help'),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
