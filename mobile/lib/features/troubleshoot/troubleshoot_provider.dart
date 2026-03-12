import 'package:flutter/material.dart';
import '../../data/models/device_model.dart';
import '../../data/troubleshoot_data.dart';

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
  String _resolutionNote = '';

  final Set<int>    _completedSteps = {};
  final Map<int, String> _stepNotes = {};

  int  get currentStep      => _currentStep;
  bool get isResolved       => _isResolved;
  bool get showingResult    => _showingResult;
  int  get totalSteps       => scenario.steps.length;
  bool get isLastStep       => _currentStep >= scenario.steps.length - 1;
  bool get allStepsComplete => _completedSteps.length == scenario.steps.length;
  Set<int> get completedSteps => _completedSteps;
  String get resolutionNote => _resolutionNote;

  TroubleshootStep get currentStepData => scenario.steps[_currentStep];

  bool    isStepCompleted(int index) => _completedSteps.contains(index);
  String? getStepNote(int index)     => _stepNotes[index];

  double get progressPct =>
      _completedSteps.length / scenario.steps.length;

  void completeCurrentStep({String? note}) {
    _completedSteps.add(_currentStep);
    if (note != null && note.isNotEmpty) _stepNotes[_currentStep] = note;
    if (!isLastStep) _currentStep++;
    notifyListeners();
  }

  void toggleStep(int index) {
    if (_completedSteps.contains(index)) {
      _completedSteps.remove(index);
    } else {
      _completedSteps.add(index);
    }
    notifyListeners();
  }

  void setResolutionNote(String note) {
    _resolutionNote = note;
  }

  void goToStep(int index) {
    if (index >= 0 && index < scenario.steps.length) {
      _currentStep = index;
      notifyListeners();
    }
  }

  void markResolved() {
    _isResolved    = true;
    _showingResult = true;
    notifyListeners();
  }

  void escalate() {
    _showingResult = true;
    notifyListeners();
  }

  void restart() {
    _currentStep   = 0;
    _isResolved    = false;
    _showingResult = false;
    _resolutionNote = '';
    _completedSteps.clear();
    _stepNotes.clear();
    notifyListeners();
  }
}
