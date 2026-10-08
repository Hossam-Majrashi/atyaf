import 'package:window_manager/window_manager.dart';

import '../../shared/services/process_service.dart';

/// Close the desktop window, not the programs launched from it. The hidden
/// supervisor must retain its pipes until all local output and exits are saved.
/// Profiles owned by another Atyaf instance do not delay this window's shutdown.
Future<void> closeDesktopWindow(ProcessService processes) async {
  await windowManager.hide();
  await processes.waitForPendingExits(timeout: null);
  await windowManager.destroy();
}
