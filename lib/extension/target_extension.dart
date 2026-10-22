import 'dart:io';

extension Target on Object {
  bool isAndroid() {
    return Platform.isAndroid;
  }

  bool isIOS() {
    return Platform.isIOS;
  }
}