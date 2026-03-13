import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get appTitle => Intl.message('lbpSSH',
      name: 'appTitle', locale: locale.toString());
  String get connect =>
      Intl.message('连接', name: 'connect', locale: locale.toString());
  String get disconnect => Intl.message('断开',
      name: 'disconnect', locale: locale.toString());
  String get noConnection => Intl.message('暂无保存的连接',
      name: 'noConnection', locale: locale.toString());
  String get createLocalTerminal => Intl.message('创建本地终端',
      name: 'createLocalTerminal', locale: locale.toString());
  String get clickToConnect => Intl.message('点击左侧连接以打开终端',
      name: 'clickToConnect', locale: locale.toString());
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
