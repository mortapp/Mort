import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

extension MortLocalizationContext on BuildContext {
  MortLocalizations get mortL10n =>
      Localizations.of<MortLocalizations>(this, MortLocalizations) ??
      MortLocalizationsEn();
}
