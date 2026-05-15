import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void goToHome() => setIndex(0);
  void goToVocabulary() => setIndex(1);
  void goToQuestionBank() => setIndex(2);
  void goToAiAssistant() => setIndex(3);
  void goToProfile() => setIndex(4);
}
