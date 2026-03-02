import 'package:flutter/material.dart';
import '../../data/troubleshoot_data.dart';
import '../../data/models/device_model.dart';

/// TroubleshootProvider manages the state of the troubleshooting wizard.
/// It tracks which step the technician is on, which steps are marked
/// done, and whether the overall issue has been resolved.
class TroubleshootProvider extends ChangeNotifier {

  final DeviceModel          device;
  final TroubleshootScenario scenario;
  final double?              measuredValue;
  final double?              threshold;

  TroubleshootProvider({
    required this.device,
    required this.scenario,
    this.measuredValue,
    this.threshold,
  });

  int  _currentStep   = 0;
  bool _isResolved    = false;
  bool _showingResult = false;

  // Which steps the technician has marked as done
  final Set<int> _completedSteps = {};

  // Notes the technician can add to each step
  final Map<int, String> _stepNotes = {};

  int  get currentStep      => _currentStep;
  bool get isResolved       => _isResolved;
  bool get showingResult    => _showingResult;
  int  get totalSteps       => scenario.steps.length;
  bool get isLastStep       => _currentStep >= scenario.steps.length - 1;
  bool get allStepsComplete => _completedSteps.length == scenario.steps.length;
  Set<int> get completedSteps => _completedSteps;

  TroubleshootStep get currentStepData =>
      scenario.steps[_currentStep];

  bool isStepCompleted(int index) => _completedSteps.contains(index);
  String? getStepNote(int index)  => _stepNotes[index];

  /// Marks the current step as done and advances to the next.
  void completeCurrentStep({String? note}) {
    _completedSteps.add(_currentStep);
    if (note != null && note.isNotEmpty) {
      _stepNotes[_currentStep] = note;
    }
    if (!isLastStep) {
      _currentStep++;
    }
    notifyListeners();
  }

  /// Allows the technician to jump to a specific step.
  void goToStep(int index) {
    if (index >= 0 && index < scenario.steps.length) {
      _currentStep = index;
      notifyListeners();
    }
  }

  /// Called when all steps are complete and the issue is resolved.
  void markResolved() {
    _isResolved    = true;
    _showingResult = true;
    notifyListeners();
  }

  /// Called when the technician skips to the end without completing all steps.
  void escalate() {
    _showingResult = true;
    notifyListeners();
  }

  /// Resets the wizard to start from the beginning.
  void restart() {
    _currentStep   = 0;
    _isResolved    = false;
    _showingResult = false;
    _completedSteps.clear();
    _stepNotes.clear();
    notifyListeners();
  }

  double get progressPct =>
      _completedSteps.length / scenario.steps.length;
}