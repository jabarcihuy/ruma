import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/auth_session.dart';
import '../data/push_notifications.dart';
import '../data/reminders.dart';
import '../features/agenda/agenda_detail.dart';
import '../features/notifications/notification_pages.dart';
import '../data/assistant_store.dart';
import '../data/assistant_service.dart';
import '../data/draft_repository.dart';
import '../features/assistant/assistant_page.dart';
import '../data/agenda_repository.dart';
import '../data/finance_repository.dart';
import '../data/savings_repository.dart';
import '../data/savings_store.dart';
import '../data/finance.dart';
import '../data/user_settings.dart';
import '../features/finance/finance_page.dart';
import '../features/agenda/agenda_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../ui/components.dart';
import 'theme.dart';
import '../data/schedule_import_repository.dart';
import '../data/schedule_images.dart';
import '../features/assistant/schedule_import_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.session,
    this.firestore,
    this.notifications,
  });
  final AuthSession session;
  final FirebaseFirestore? firestore;
  final RumaNotifications? notifications;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  Future<void> Function()? _previousSignOut;
  Future<void> _beforeSignOut() async {
    await _assistant?.flush();
    if (Platform.isAndroid) await ScheduleImages(_uid).clear();
    await _previousSignOut?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive &&
        _assistant?.storagePending == true) {
      unawaited(_assistant!.flush());
    }
  }

  int _tab = 0;
  UserSettingsStore? _settings;
  int _settingsRevision = -1;
  void _settingsChanged() {
    if (!mounted) return;
    _agenda?.defaultDurationMinutes =
        _settings?.ready == true && _settings!.value.personalize
        ? _settings!.value.duration
        : 60;
    if (_settings?.ready == true && _settings!.revision != _settingsRevision) {
      final replace = _settingsRevision >= 0;
      _settingsRevision = _settings!.revision;
      _assistant?.applyPersonalDefaults(replace: replace);
    }
    setState(() {});
  }

  AgendaStore? _agenda;
  FinanceStore? _finance;
  SavingsStore? _savings;
  void _savingsChanged() {
    if (_savings?.saving != false ||
        _savings?.loading != false ||
        _savings?.snapshot == null ||
        _finance?.loading != false ||
        _finance?.error != null) {
      return;
    }
    if (_savings!.snapshot!.revision != _finance?.snapshot?.revision) {
      unawaited(_finance!.load());
    }
  }

  void _financeChanged() {
    if (_savings == null || _savings!.saving) return;
    if (_finance!.loading || _finance!.error != null) {
      _savings!.invalidate();
    } else {
      unawaited(_savings!.load());
    }
  }

  AssistantStore? _assistant;
  late final String _uid;
  @override
  void initState() {
    super.initState();
    _uid = widget.session.account!.uid;
    if (widget.firestore != null) {
      _settings = UserSettingsStore(widget.firestore!, FirebaseAuth.instance)
        ..addListener(_settingsChanged);
      _settings!.load();
      _agenda = AgendaStore(
        AgendaRepository(widget.firestore!, FirebaseAuth.instance),
      );
      _agenda!.notifications = widget.notifications;
      _agenda!.load();
      _finance = FinanceStore(
        FinanceRepository(widget.firestore!, FirebaseAuth.instance),
      );
      _savings = SavingsStore(
        SavingsRepository(widget.firestore!, FirebaseAuth.instance),
        onCommitted: () => _finance!.load(),
      );
      _savings!.addListener(_savingsChanged);
      _finance!.addListener(_financeChanged);
      _finance!.load();
      _assistant = AssistantStore(
        DraftRepository(widget.firestore!, FirebaseAuth.instance),
        AssistantService(FirebaseAuth.instance),
        _agenda!,
        _finance!,
        persistent: true,
        settings: _settings,
      );
      _assistant!.load();
      if (Platform.isAndroid) unawaited(_recoverScheduleImages());
      _previousSignOut = widget.session.beforeSignOut;
      widget.session.beforeSignOut = _beforeSignOut;
    }
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_sessionChanged);
    widget.notifications?.addListener(_notificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notificationTap());
  }

  Future<void> _recoverScheduleImages() async {
    try {
      final count = await ScheduleImages(_uid).recover();
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gambar jadwal dipulihkan. Buka Impor jadwal di Asisten untuk melanjutkan.',
            ),
          ),
        );
      }
    } catch (_) {
      /* A missing cache never triggers a model call or overwrites a draft. */
    }
  }

  Future<void> _openScheduleImport() async {
    if (_assistant == null || widget.firestore == null || !_assistant!.usable) {
      return;
    }
    final openAgenda = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleImportPage(
          assistant: _assistant!,
          repository: ScheduleImportRepository(
            widget.firestore!,
            FirebaseAuth.instance,
          ),
        ),
      ),
    );
    if (mounted && openAgenda == true) _select(1);
  }

  bool _openingNotification = false;
  Future<void> _notificationTap() async {
    if (!mounted ||
        _openingNotification ||
        widget.notifications?.pending == null ||
        _agenda == null) {
      return;
    }
    _openingNotification = true;
    final target = widget.notifications!.takePending()!;
    try {
      if (target.uid != _uid || widget.session.account?.uid != _uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Masuk dengan akun pemilik notifikasi untuk melihat agenda.',
            ),
          ),
        );
        return;
      }
      await _agenda!.load();
      if (!mounted || widget.session.account?.uid != _uid) return;
      if (_agenda!.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_agenda!.error!)));
        return;
      }
      Navigator.of(context).popUntil((r) => r.isFirst);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AgendaDetailPage(
            store: _agenda!,
            id: target.occurrenceDate == null
                ? target.agendaId
                : '${target.agendaId}__${target.occurrenceDate}',
            notifications: widget.notifications,
            notificationVersion: target.sourceVersion,
          ),
        ),
      );
    } finally {
      _openingNotification = false;
      if (mounted && widget.notifications?.pending != null) _notificationTap();
    }
  }

  void _sessionChanged() {
    if (widget.session.account?.uid != _uid) {
      final navigator = Navigator.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.session.beforeSignOut == _beforeSignOut) {
      widget.session.beforeSignOut = _previousSignOut;
    }
    widget.session.removeListener(_sessionChanged);
    widget.notifications?.removeListener(_notificationTap);
    _settings?.removeListener(_settingsChanged);
    _settings?.dispose();
    _assistant?.dispose();
    _agenda?.dispose();
    _finance?.removeListener(_financeChanged);
    _savings?.removeListener(_savingsChanged);
    _savings?.dispose();
    _finance?.dispose();
    super.dispose();
  }

  static const labels = ['Beranda', 'Agenda', 'Asisten', 'Keuangan', 'Profil'];
  static const icons = ['house', 'calendar-days', '', 'wallet', 'user-round'];
  void _select(int index) {
    if (_tab != index) {
      if (index == 0) {
        unawaited(_agenda?.load());
        unawaited(_finance?.load(financeToday().substring(0, 7)));
      }
      setState(() => _tab = index);
    }
  }

  Widget _navigationItem(int index) => Expanded(
    child: Semantics(
      selected: _tab == index,
      button: true,
      label: labels[index],
      excludeSemantics: true,
      child: Tooltip(
        message: labels[index],
        child: InkWell(
          key: ValueKey('tab-$index'),
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            _select(index);
          },
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (index == 2)
                  SizedBox.square(
                    dimension: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        SvgPicture.asset(
                          'design/assets/ruma/mascot/nav-circle.svg',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                        SvgPicture.asset(
                          'design/assets/ruma/mascot/nav-face.svg',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                        if (_tab == index)
                          const Positioned(
                            bottom: -5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: RumaColors.accent,
                              ),
                              child: SizedBox.square(dimension: 4),
                            ),
                          ),
                      ],
                    ),
                  )
                else ...[
                  const SizedBox(height: 9),
                  RumaIcon(
                    icons[index],
                    color: _tab == index ? RumaColors.accent : RumaColors.muted,
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _tab == index
                          ? RumaColors.accent
                          : Colors.transparent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final account = widget.session.account!;
    final page = switch (_tab) {
      0 => HomePage(
        account: account,
        onTab: _select,
        agenda: _agenda,
        finance: _finance,
        savings: _savings,
      ),
      1 =>
        _agenda != null
            ? AgendaPage(
                key: ValueKey('agenda-$_uid'),
                store: _agenda!,
                onImport: _openScheduleImport,
              )
            : const _SectionIntro(
                title: 'Agendamu, lebih tertata.',
                subtitle: 'Ruang untuk jadwal kuliah, kegiatan, dan tugas.',
                asset: 'illustrations/illustration-calendar.svg',
                caption: 'Mulai dari kegiatan yang paling dekat. Kamu tetap bisa menentukan waktu dan durasinya sendiri.',
              ),
      2 =>
        _assistant != null
            ? AssistantPage(
                key: ValueKey('assistant-$_uid'),
                store: _assistant!,
                keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
                onTab: _select,
                onImport: _openScheduleImport,
              )
            : const _SectionIntro(
                title: 'Mau dibantu apa?',
                subtitle: 'Teman untuk mengelola waktu dan uangmu.',
                asset: 'mascot/abstract-friend.svg',
                caption: 'Ceritakan kebutuhanmu, tinjau drafnya, lalu putuskan perubahan yang ingin disimpan.',
              ),
      3 =>
        _finance != null
            ? FinancePage(
                key: ValueKey('finance-$_uid'),
                store: _finance!,
                onAssistant: () => _select(2),
                savings: _savings,
                navigationBuilder: _bottomNavigation,
              )
            : const _SectionIntro(
                title: 'Uangmu punya arah.',
                subtitle: 'Kenali kebiasaanmu, satu catatan setiap hari.',
                asset: 'illustrations/illustration-wallet.svg',
                caption: 'Pemasukan, pengeluaran, dan tabungan membantu melihat uang yang sudah kamu catat.',
              ),
      _ => ProfilePage(
        session: widget.session,
        settings: _settings,
        onNotifications: widget.notifications == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => NotificationsPage(
                    notifications: widget.notifications!,
                    repository: ReminderRepository(
                      widget.firestore!,
                      FirebaseAuth.instance,
                    ),
                  ),
                ),
              ),
      ),
    };
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 24,
          title: Text(
            _tab == 0 ? 'ruma' : labels[_tab],
            style: _tab == 0
                ? Theme.of(context).textTheme.titleLarge
                : Theme.of(context).textTheme.titleMedium,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: AnimatedSwitcher(
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 180,
                ),
                child: _tab == 2 && _assistant != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: page,
                      )
                    : SingleChildScrollView(
                        key: ValueKey('${account.uid}-$_tab'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.session.notice != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: RumaCard(
                                  color: RumaColors.soft,
                                  child: Text(widget.session.notice!),
                                ),
                              ),
                            page,
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: _bottomNavigation(),
      ),
    );
  }

  Widget? _bottomNavigation() => MediaQuery.viewInsetsOf(context).bottom > 0
      ? null
      : SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                height: 64,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RumaColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1420241F),
                      offset: Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(children: List.generate(5, _navigationItem)),
              ),
            ),
          ),
        );
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.caption,
  });
  final String title, subtitle, asset, caption;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RumaHeading(title, subtitle),
      const SizedBox(height: 24),
      RumaCard(
        color: RumaColors.sage,
        padding: 24,
        child: Column(
          children: [
            SvgPicture.asset(
              'design/assets/ruma/$asset',
              width: 200,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ],
  );
}
