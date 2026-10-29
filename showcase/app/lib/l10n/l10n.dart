import 'package:flutter/widgets.dart';
import 'package:waypoint/l10n/app_localizations.dart';

export 'package:waypoint/l10n/app_localizations.dart';

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
