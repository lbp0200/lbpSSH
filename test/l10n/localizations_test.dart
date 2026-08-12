import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations Tests', () {
    group('Chinese localization', () {
      late AppLocalizations zh;

      setUp(() {
        zh = AppLocalizations(const Locale('zh'));
      });

      test('appTitle', () {
        expect(zh.appTitle, 'lbpSSH');
      });

      test('connect', () {
        expect(zh.connect, '连接');
      });

      test('disconnect', () {
        expect(zh.disconnect, '断开');
      });

      test('noConnection', () {
        expect(zh.noConnection, '暂无保存的连接');
      });

      test('createLocalTerminal', () {
        expect(zh.createLocalTerminal, '创建本地终端');
      });

      test('clickToConnect', () {
        expect(zh.clickToConnect, '点击左侧连接以打开终端');
      });

      test('disconnected', () {
        expect(zh.disconnected, '已断开');
      });

      test('reconnect', () {
        expect(zh.reconnect, '重连');
      });

      test('reconnecting', () {
        expect(zh.reconnecting, '正在重连...');
      });

      test('connectionLost', () {
        expect(zh.connectionLost, '连接已断开');
      });

      test('local', () {
        expect(zh.local, '本地');
      });

      test('connecting', () {
        expect(zh.connecting, '连接中...');
      });

      test('connected', () {
        expect(zh.connected, '已连接');
      });

      test('reconnectFailed', () {
        expect(zh.reconnectFailed, '重连失败');
      });
    });

    group('English localization', () {
      late AppLocalizations en;

      setUp(() {
        en = AppLocalizations(const Locale('en'));
      });

      test('appTitle', () {
        expect(en.appTitle, 'lbpSSH');
      });

      test('connect', () {
        expect(en.connect, 'Connect');
      });

      test('disconnect', () {
        expect(en.disconnect, 'Disconnect');
      });

      test('noConnection', () {
        expect(en.noConnection, 'No saved connections');
      });

      test('createLocalTerminal', () {
        expect(en.createLocalTerminal, 'Create Local Terminal');
      });

      test('clickToConnect', () {
        expect(en.clickToConnect, 'Click a connection on the left to open terminal');
      });

      test('disconnected', () {
        expect(en.disconnected, 'Disconnected');
      });

      test('reconnect', () {
        expect(en.reconnect, 'Reconnect');
      });

      test('reconnecting', () {
        expect(en.reconnecting, 'Reconnecting...');
      });

      test('connectionLost', () {
        expect(en.connectionLost, 'Connection lost');
      });

      test('local', () {
        expect(en.local, 'Local');
      });

      test('connecting', () {
        expect(en.connecting, 'Connecting...');
      });

      test('connected', () {
        expect(en.connected, 'Connected');
      });

      test('reconnectFailed', () {
        expect(en.reconnectFailed, 'Reconnect failed');
      });
    });

    group('delegate', () {
      test('should support Chinese locale', () {
        expect(AppLocalizations.delegate.isSupported(const Locale('zh')), isTrue);
      });

      test('should support English locale', () {
        expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      });

      test('should not support unsupported locale', () {
        expect(
          AppLocalizations.delegate.isSupported(const Locale('fr')),
          isFalse,
        );
      });

      test('should load localization for zh', () async {
        final localizations = await AppLocalizations.delegate.load(
          const Locale('zh'),
        );

        expect(localizations.connect, '连接');
      });

      test('should load localization for en', () async {
        final localizations = await AppLocalizations.delegate.load(
          const Locale('en'),
        );

        expect(localizations.connect, 'Connect');
      });

      test('shouldReload returns false for same delegate', () {
        expect(
          AppLocalizations.delegate.shouldReload(AppLocalizations.delegate),
          isFalse,
        );
      });
    });
  });
}
