import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../../data/troubleshoot_data.dart';
import 'troubleshoot_provider.dart';

class TroubleshootScreen extends StatelessWidget {
  const TroubleshootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    DeviceModel device;
    String      alertType;
    double?     value;
    double?     threshold;

    // Arguments can come from two sources:
    // 1. A Map from the diagnostic screen with full context
    // 2. A DeviceModel directly from the device detail screen
    if (args is Map) {
      device    = args['device']    as DeviceModel;
      alertType = args['alertType'] as String? ?? 'generic';
      // checkName removed
      value     = args['value']     as double?;
      threshold = args['threshold'] as double?;
    } else if (args is DeviceModel) {
      device    = args;
      alertType = 'generic';
      // checkName removed
      value     = null;
      threshold = null;
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Troubleshoot')),
        body: const Center(child: Text('No device data provided.')),
      );
    }

    // Get the correct troubleshooting scenario for this alert type
    final scenario = TroubleshootData.getScenario(
      alertType:  alertType,
      deviceType: device.deviceType,
    );

    return ChangeNotifierProvider(
      create: (_) => TroubleshootProvider(
        device:         device,
        scenario:       scenario,
        measuredValue:  value,
        threshold:      threshold,
      ),
      child: _TroubleshootContent(
        device:    device,
        alertType: alertType,
        value:     value,
        threshold: threshold,
      ),
    );
  }
}

class _TroubleshootContent extends StatelessWidget {
  final DeviceModel device;
  final String      alertType;
  final double?     value;
  final double?     threshold;

  const _TroubleshootContent({
    required this.device,
    required this.alertType,
    this.value,
    this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TroubleshootProvider>(
      builder: (context, provider, _) {

        if (provider.showingResult) {
          return _buildResultScreen(context, provider);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Troubleshoot'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(6),
              child: LinearProgressIndicator(
                value:            provider.progressPct,
                backgroundColor:  Colors.white24,
                valueColor:       const AlwaysStoppedAnimation<Color>(
                    Colors.white),
                minHeight: 4,
              ),
            ),
          ),
          body: Column(
            children: [

              // ── Header — Scenario Title and Device ───────────────────
              _buildHeader(context, provider),

              // ── Step Navigator — small clickable step dots ───────────
              _buildStepNav(context, provider),

              const Divider(height: 1),

              // ── Current Step Content ─────────────────────────────────
              Expanded(
                child: _buildStepContent(context, provider),
              ),

              // ── Bottom Action Bar ────────────────────────────────────
              _buildBottomBar(context, provider),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, TroubleshootProvider provider) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color:   AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scenario title
          Text(
            provider.scenario.title,
            style: const TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Device context
          Row(
            children: [
              Icon(AppUtils.deviceTypeIcon(device.deviceType),
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 5),
              Text(
                '${device.name}  ·  ${device.ipAddress}',
                style: const TextStyle(
                  fontSize: 13,
                  color:    AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Measured value context if available
          if (value != null && threshold != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:    const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        AppColors.offlineLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber,
                      size: 14, color: AppColors.offline),
                  const SizedBox(width: 6),
                  Text(
                    'Measured: ${value!.toStringAsFixed(1)}'
                    '  |  Threshold: ${threshold!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize:   12,
                      color:      AppColors.offline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Scenario description
          Text(
            provider.scenario.description,
            style: const TextStyle(
              fontSize: 13,
              color:    AppColors.textSecondary,
              height:   1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step Navigator — row of numbered dots
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStepNav(BuildContext context, TroubleshootProvider provider) {
    return Container(
      color:   AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(provider.totalSteps, (index) {
          final isCurrent   = index == provider.currentStep;
          final isCompleted = provider.isStepCompleted(index);

          return Expanded(
            child: GestureDetector(
              onTap: () => provider.goToStep(index),
              child: Row(
                children: [
                  // Step dot
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width:    isCurrent ? 32 : 24,
                    height:   24,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.online
                          : isCurrent
                              ? AppColors.primary
                              : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.bold,
                                color: isCurrent
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                    ),
                  ),

                  // Connector line between dots
                  if (index < provider.totalSteps - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted
                            ? AppColors.online.withOpacity(0.4)
                            : AppColors.divider,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step Content
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStepContent(BuildContext context, TroubleshootProvider provider) {
    final step      = provider.currentStepData;
    final stepIndex = provider.currentStep;
    final isDone    = provider.isStepCompleted(stepIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Step number and title
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Step ${stepIndex + 1} of ${provider.totalSteps}',
                  style: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.bold,
                    color:      AppColors.primary,
                  ),
                ),
              ),
              if (step.isCritical) ...[
                const SizedBox(width: 8),
                Container(
                  padding:    const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        AppColors.offlineLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber,
                          size: 12, color: AppColors.offline),
                      SizedBox(width: 4),
                      Text(
                        'Critical Step',
                        style: TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.offline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          Text(
            step.title,
            style: const TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.bold,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Instruction box
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_outlined,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'What to do',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   13,
                        color:      AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.instruction,
                  style: const TextStyle(
                    fontSize: 14,
                    color:    AppColors.textPrimary,
                    height:   1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // CLI Command box (if there is a command)
          if (step.command != null) ...[
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal,
                          size: 14, color: Colors.green),
                      SizedBox(width: 6),
                      Text(
                        'Command to run',
                        style: TextStyle(
                          color:      Colors.green,
                          fontSize:   12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.command!,
                    style: const TextStyle(
                      color:      Color(0xFF00FF41),
                      fontSize:   13,
                      fontFamily: 'monospace',
                      height:     1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Expected result box
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        AppColors.onlineLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.online.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.online),
                    SizedBox(width: 6),
                    Text(
                      'Expected result',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   13,
                        color:      AppColors.online,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.expectedResult,
                  style: const TextStyle(
                    fontSize: 13,
                    color:    AppColors.textPrimary,
                    height:   1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Warning note if there is one
          if (step.warningNote != null) ...[
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColors.degradedLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.degraded.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 18, color: AppColors.degraded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.warningNote!,
                      style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textPrimary,
                        height:   1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Step complete indicator
          if (isDone)
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColors.onlineLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.online, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'This step has been marked as done.',
                    style: TextStyle(
                      color:      AppColors.online,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
          // Extra space so content is not hidden behind the bottom bar
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom Action Bar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context, TroubleshootProvider provider) {
    final isDone    = provider.isStepCompleted(provider.currentStep);
    final isLast    = provider.isLastStep;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color:      Color(0x14000000),
            blurRadius: 8,
            offset:     Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Main action button
          ElevatedButton.icon(
            onPressed: () {
              if (isDone && isLast) {
                // All steps done — show resolution screen
                provider.markResolved();
              } else if (isDone) {
                // Current step done — go to next
                provider.goToStep(provider.currentStep + 1);
              } else {
                // Mark current step as complete
                provider.completeCurrentStep();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDone && isLast
                  ? AppColors.online
                  : AppColors.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(
              isDone && isLast
                  ? Icons.verified_outlined
                  : isDone
                      ? Icons.arrow_forward
                      : Icons.check,
            ),
            label: Text(
              isDone && isLast
                  ? 'Mark Issue as Resolved'
                  : isDone
                      ? 'Next Step'
                      : 'Mark Step as Done',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 8),

          // Secondary actions row
          Row(
            children: [
              // Previous step
              if (provider.currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        provider.goToStep(provider.currentStep - 1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('← Previous'),
                  ),
                ),

              if (provider.currentStep > 0) const SizedBox(width: 8),

              // Escalate — skip to resolution without completing all steps
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showEscalateDialog(context, provider),
                  style: OutlinedButton.styleFrom(
                    minimumSize:    const Size(0, 42),
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Escalate Issue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEscalateDialog(
      BuildContext context, TroubleshootProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Escalate Issue?'),
        content: const Text(
          'This will mark the issue for escalation to a senior technician '
          'or network engineer. The troubleshooting session will be saved '
          'with the steps completed so far.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.escalate();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.offline),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Resolution Screen — shown after all steps are complete
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResultScreen(
      BuildContext context, TroubleshootProvider provider) {
    final resolved      = provider.isResolved;
    final completedCount = provider.completedSteps.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Resolution'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Result banner
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: resolved
                    ? AppColors.onlineLight
                    : AppColors.degradedLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: resolved
                      ? AppColors.online.withOpacity(0.4)
                      : AppColors.degraded.withOpacity(0.4),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    resolved
                        ? Icons.verified
                        : Icons.escalator_warning,
                    size:  56,
                    color: resolved
                        ? AppColors.online
                        : AppColors.degraded,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    resolved
                        ? 'Issue Resolved'
                        : 'Issue Escalated',
                    style: TextStyle(
                      fontSize:   24,
                      fontWeight: FontWeight.bold,
                      color: resolved
                          ? AppColors.online
                          : AppColors.degraded,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolved
                        ? provider.scenario.resolution
                        : 'This issue has been flagged for escalation '
                            'to a senior engineer. The steps completed '
                            'have been recorded.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color:    AppColors.textSecondary,
                      height:   1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Session summary
            Container(
              padding:    const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   15,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _SummaryRow(
                    label: 'Device',
                    value: provider.device.name,
                  ),
                  _SummaryRow(
                    label: 'Issue',
                    value: provider.scenario.title,
                  ),
                  _SummaryRow(
                    label: 'Steps Completed',
                    value: '$completedCount of ${provider.totalSteps}',
                  ),
                  _SummaryRow(
                    label: 'Outcome',
                    value: resolved ? 'Resolved' : 'Escalated',
                    valueColor: resolved
                        ? AppColors.online
                        : AppColors.degraded,
                  ),

                  // Show completed step titles
                  if (provider.completedSteps.isNotEmpty) ...[
                    const Divider(height: 20),
                    const Text(
                      'Steps performed:',
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...provider.completedSteps.map((idx) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle,
                                  size:  14,
                                  color: AppColors.online),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  provider.scenario.steps[idx].title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color:    AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            ElevatedButton.icon(
              onPressed: () {
                // Pop back to wherever we came from
                int count = 0;
                Navigator.of(context).popUntil((_) => count++ >= 2);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              icon:  const Icon(Icons.home_outlined),
              label: const Text('Back to Device',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: provider.restart,
              style: OutlinedButton.styleFrom(
                minimumSize:    const Size(double.infinity, 48),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon:  const Icon(Icons.refresh),
              label: const Text('Run Wizard Again',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Simple label-value row for the resolution summary.
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color:    AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}