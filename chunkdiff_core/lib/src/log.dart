/// Simple in-memory debug log with console echo for troubleshooting.
///
/// Use `logDebug('message')` to append and print. Logs are kept in memory
/// (capped) and can be read via `readDebugLog()`. Call `clearDebugLog()` to
/// reset between runs.

const int _kMaxLogEntriesDebug = 10000;
const int _kMaxLogEntriesRelease = 1000;
const bool _isDebug = !bool.fromEnvironment('dart.vm.product');
final List<String> _debugLog = <String>[];
bool _verboseEnabled = _isDebug;

bool isDebugBuild() => _isDebug;

void logDebug(String message) {
  // Always print for visibility in console.
  // ignore: avoid_print
  print('[chunkdiff_core] $message');
  _debugLog.add(message);
  final int cap = _isDebug ? _kMaxLogEntriesDebug : _kMaxLogEntriesRelease;
  if (_debugLog.length > cap) {
    _debugLog.removeRange(0, _debugLog.length - cap);
  }
}

List<String> readDebugLog({int? maxEntries}) {
  if (maxEntries == null || maxEntries <= 0 || maxEntries >= _debugLog.length) {
    return List<String>.from(_debugLog);
  }
  final int start = _debugLog.length - maxEntries;
  return _debugLog.sublist(start);
}

void clearDebugLog() {
  _debugLog.clear();
}

void setVerboseLogging(bool enabled) {
  _verboseEnabled = enabled;
}

void logVerbose(String message) {
  if (!_verboseEnabled) {
    return;
  }
  logDebug(message);
}
