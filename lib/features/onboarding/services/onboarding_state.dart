import 'package:flutter/foundation.dart';

class OnboardingState extends ChangeNotifier {
  int step = 0;
  void advance() {
    if (step < 2) {
      step++;
      notifyListeners();
    }
  }
}
