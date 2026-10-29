import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/agenda.dart';
import '../../data/assistant_draft.dart';
import '../../data/assistant_service.dart';
import '../../data/assistant_store.dart';
import '../../data/finance.dart' show dateKey;
import '../../data/conversation.dart';
import '../../data/google_calendar_service.dart';
import '../../data/schedule_images.dart';
import '../../data/schedule_import.dart';
import '../../data/schedule_import_repository.dart';
import '../../ui/components.dart';

class ScheduleImportPage extends StatefulWidget {
  const ScheduleImportPage({
    super.key,
    required this.assistant,
    required this.repository,
    this.calendar,
    this.images,
  });
  final AssistantStore assistant;
  final ScheduleImportRepository repository;
  final GoogleCalendarService? calendar;
  final ScheduleImages? images;
  @override
  State<ScheduleImportPage> createState() => _ScheduleImportPageState();
}

class _ScheduleImportPageState extends State<ScheduleImportPage> {
  late final GoogleCalendarService _calendar;
  late final ScheduleImages _imageStore;
  List<ScheduleImage> _images = [];
  List<CalendarChoice> _calendars = [];
  String? _calendarId, _from, _to;
  String _source = 'image', _error = '', _note = '';
  bool _busy = false, _committing = false, _correctionConsent = false;
  int _generation = 0;
  ScheduleReadCancellation? _cancellation;
  ScheduleWorkspace? _workspace;
  ImportPreview? _preview;
  final _correction = TextEditingController();
  final _successKey = GlobalKey();
  void _revealSuccess() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = _successKey.currentContext;
    if (mounted && target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
        alignment: .1,
      );
    }
  });
  static const days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  @override
  void initState() {
    super.initState();
    _calendar =
        widget.calendar ??
        GoogleCalendarService(checkSession: widget.repository.check);
    _imageStore = widget.images ?? ScheduleImages(widget.repository.uid);
    final saved = widget.assistant.scheduleWorkspace;
    if (saved != null) {
      try {
        _workspace = ScheduleWorkspace.fromJson(saved);
        _source = _workspace!.rows.any((r) => r.provider == 'google')
            ? 'google'
            : 'image';
        if (_workspace!.periodConfirmed) {
          _from = _workspace!.from;
          _to = _workspace!.to;
        }
      } catch (_) {
        _error =
            'Tinjauan sebelumnya belum dapat dibaca. Data lama tidak ditimpa.';
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    try {
      final images = await _imageStore.pending();
      if (!mounted) return;
      setState(() => _images = images);
      if (_workspace != null && !_workspace!.locked) await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Lampiran belum pulih. Pilih kembali gambar jika diperlukan.',
        );
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _cancellation?.cancel();
    _calendar.close();
    _correction.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = e is DraftFailure
              ? e.message
              : e is AgendaFailure
              ? e.message
              : 'Belum dapat melanjutkan. Isian dan tinjauan tetap tersedia.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<bool> _persist() async {
    if (_workspace == null) return true;
    widget.assistant.updateScheduleWorkspace(_workspace!.toJson());
    return widget.assistant.flush();
  }

  Future<void> _refresh() async {
    final w = _workspace;
    if (w == null || w.locked) return;
    final revision = w.revision;
    final preview = await widget.repository.preview(w);
    if (!mounted || _workspace != w || w.revision != revision) return;
    setState(() => _preview = preview);
    if (!await _persist() && mounted) {
      setState(
        () => _error = 'Tinjauan belum tersimpan. Coba simpan kembali sebelum menutup aplikasi.',
      );
    }
  }

  Future<bool> _replace() async {
    final w = _workspace;
    if (w?.attempted == true && !w!.applied) {
      setState(
        () => _error =
            'Periksa hasil penyimpanan sebelumnya sebelum mengganti impor.',
      );
      return false;
    }
    if (w == null || w.applied) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => RumaDialog(
            title: const Text('Ganti usulan impor?'),
            content: const Text(
              'Usulan yang belum disimpan akan diganti. Agenda yang sudah tersimpan tetap ada.',
            ),
            actions: [
              RumaButton(
                label: 'Pertahankan',
                secondary: true,
                onPressed: () => Navigator.pop(c, false),
              ),
              const SizedBox(height: 8),
              RumaButton(
                label: 'Ganti usulan',
                onPressed: () => Navigator.pop(c, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _date(bool first) async {
    final now = agendaLocal(DateTime.now().toUtc());
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.parse((first ? _from : _to) ?? dateKey(now)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (first) {
        _from = dateKey(date);
      } else {
        _to = dateKey(date);
      }
      final w = _workspace;
      if (w != null && !w.locked) {
        if (w.rows.any((r) => r.provider == 'google')) {
          w.periodConfirmed = false;
          _note = 'Periode berubah. Ambil ulang jadwal Google untuk memeriksa seluruh pertemuan.';
        } else {
          w.from = _from ?? w.from;
          w.to = _to ?? w.to;
          w.periodConfirmed = _from != null && _to != null;
        }
        w.changed();
        _preview = null;
      }
    });
    if (_workspace != null && !_workspace!.locked) await _run(_refresh);
  }

  Future<void> _pick() async {
    if (!await _replace() || !mounted) return;
    await _run(() async {
      final generation = _generation;
      final images = await _imageStore.pick();
      widget.repository.check();
      if (!mounted || generation != _generation || images.isEmpty) return;
      setState(() {
        _images = images;
        _source = 'image';
        _workspace = null;
        _preview = null;
      });
      widget.assistant.updateScheduleWorkspace(null);
      await widget.assistant.flush();
    });
  }

  Future<void> _extract() async {
    if (_images.isEmpty || !await _replace() || !mounted) return;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (c) => RumaDialog(
        title: const Text('Baca gambar dengan Asisten?'),
        content: const Text(
          'Gambar pilihanmu dikirim melalui Ruma ke NaraRouter untuk membaca jadwal. Periksa identitas yang terlihat sebelum mengirim. Hasilnya masih usulan dan baru masuk Agenda setelah disetujui.',
        ),
        actions: [
          RumaButton(
            label: 'Batalkan',
            secondary: true,
            onPressed: () => Navigator.pop(c, false),
          ),
          const SizedBox(height: 8),
          RumaButton(
            label: 'Izinkan dan baca',
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    await _run(() async {
      final cancellation = ScheduleReadCancellation();
      _cancellation = cancellation;
      final result = await widget.assistant.service.extractSchedule(
        _images.map((i) => i.bytes).toList(),
        List.filled(_images.length, 'image/png'),
        cancellation: cancellation,
      );
      widget.repository.check();
      if (!mounted || cancellation.cancelled) return;
      final now = dateKey(agendaLocal(DateTime.now().toUtc()));
      final note = result['note'] as String? ?? '';
      final rows = (result['rows'] as List).map((item) {
        final r = Map<String, dynamic>.from(item as Map);
        return ScheduleRow(
          id: widget.repository.newId(),
          title: r['title'] as String? ?? '',
          weekday: r['weekday'] as int?,
          start: r['start'] as String? ?? '',
          end: r['end'] as String? ?? '',
          location: r['location'] as String? ?? '',
          imageIndex: r['sourceImage'] as int?,
          issue: [
            if ((r['issue'] as String? ?? '').isNotEmpty) r['issue'] as String,
            if (RegExp(r'\b(WITA|WIT)\b').hasMatch(note))
              'Periksa konversi jam ke WIB.',
          ].join(' '),
        );
      }).toList();
      setState(() {
        _workspace = ScheduleWorkspace(
          id: widget.repository.newId(),
          from: _from ?? now,
          to: _to ?? now,
          rows: rows,
          periodConfirmed: _from != null && _to != null,
        );
        _note = note;
        _preview = null;
      });
      await _refresh();
    });
  }

  Future<void> _connect() async => _run(() async {
    final generation = _generation;
    await _calendar.authorize();
    final calendars = await _calendar.calendars();
    widget.repository.check();
    if (!mounted || generation != _generation) return;
    setState(() {
      _calendars = calendars;
      _calendarId = null;
      _source = 'google';
    });
  });
  Future<void> _loadGoogle() async {
    if (_calendarId == null ||
        _from == null ||
        _to == null ||
        !await _replace() ||
        !mounted) {
      return;
    }
    await _run(() async {
      final generation = _generation;
      final id = _calendarId!, from = _from!, to = _to!;
      final previous = await widget.repository.previousSources(
        _calendar.calendarKey(id),
      );
      final rows = await _calendar.schedules(
        id,
        from,
        to,
        previousSources: previous,
      );
      widget.repository.check();
      if (!mounted || generation != _generation) return;
      rows.sort(
        (a, b) =>
            (a.weekly ? '${a.weekday ?? 8}${a.start}' : '${a.date}${a.start}')
                .compareTo(
                  b.weekly
                      ? '${b.weekday ?? 8}${b.start}'
                      : '${b.date}${b.start}',
                ),
      );
      for (final row in rows) {
        if (!row.cancelled && row.validate(from, to) == null) {
          row.originalFingerprint = scheduleFingerprint(row.build(from, to));
        }
      }
      setState(() {
        _workspace = ScheduleWorkspace(
          id: widget.repository.newId(),
          from: from,
          to: to,
          rows: rows,
          source:
              'Google Calendar · ${_calendars.firstWhere((c) => c.id == id).title}',
          periodConfirmed: true,
        );
        _note = 'Salinan satu arah. Perubahan di Ruma tidak mengubah Google Calendar.';
        _preview = null;
      });
      await _refresh();
    });
  }

  Future<void> _edit(ScheduleRow row) async {
    if (_workspace?.locked != false) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _ScheduleRowEditor(row: row)),
    );
    if (changed == true && mounted) {
      _workspace!.changed();
      setState(() => _preview = null);
      await _run(_refresh);
    }
  }

  Future<void> _correct() async {
    final w = _workspace, text = _correction.text.trim();
    if (w == null || w.locked || text.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_correctionConsent) {
      final allowed = await showDialog<bool>(
        context: context,
        builder: (c) => RumaDialog(
          title: const Text('Koreksi jadwal lewat AI?'),
          content: const Text(
            'Nama, hari/tanggal, jam, lokasi, dan pilihan baris usulan serta percakapan koreksi dikirim melalui Ruma ke NaraRouter. Akun Google dan token akses tidak dikirim ke AI. Perubahan tetap perlu kamu setujui.',
          ),
          actions: [
            RumaButton(
              label: 'Batalkan',
              secondary: true,
              onPressed: () => Navigator.pop(c, false),
            ),
            RumaButton(
              label: 'Izinkan koreksi',
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      );
      if (allowed != true || !mounted) return;
      _correctionConsent = true;
    }
    await _run(() async {
      final generation = _generation;
      final rows = w.rows;
      final result = await widget.assistant.service.correctSchedule(
        rows.map((r) => r.toJson()).toList(),
        conversationMessages(w.corrections, text),
      );
      widget.repository.check();
      if (!mounted || _workspace != w || generation != _generation) return;
      if (result['question'] is String &&
          (result['question'] as String).isNotEmpty) {
        w.corrections = [
          ...w.corrections,
          {
            'message': text,
            'reply': result['question'] as String,
            'kind': 'clarification',
          },
        ];
        _correction.clear();
        setState(() => _note = result['question'] as String);
        await _persist();
        return;
      }
      final updates = result['updates'] as List;
      for (final item in updates) {
        final change = Map<String, dynamic>.from(item as Map),
            index = change['index'] as int;
        if (index < 0 || index >= rows.length) {
          throw const DraftFailure('Baris koreksi tidak ditemukan.');
        }
        final row = rows[index];
        row.title = change['title'] as String;
        row.weekday = change['weekday'] as int?;
        row.date = change['date'] as String?;
        row.start = change['start'] as String;
        row.end = change['end'] as String;
        row.location = change['location'] as String;
        row.included = change['included'] as bool;
        row.issue = '';
      }
      w.corrections = [
        ...w.corrections,
        {'message': text, 'reply': 'Usulan diperbarui.', 'kind': 'answer'},
      ];
      if (w.corrections.length > 8) {
        w.corrections = w.corrections.sublist(w.corrections.length - 8);
      }
      w.changed();
      _correction.clear();
      setState(() {
        _note = 'Usulan diperbarui. Belum ada perubahan di Agenda.';
        _preview = null;
      });
      await _refresh();
    });
  }

  Future<void> _continueRemaining() async {
    final w = _workspace;
    if (w == null || !w.applied || _busy) return;
    final remaining = w.rows
        .where((r) => !r.included)
        .map((r) => ScheduleRow.fromJson(r.toJson()))
        .toList();
    for (final row in remaining) {
      row.included = true;
      row.useSource = false;
    }
    setState(() {
      _workspace = ScheduleWorkspace(
        id: widget.repository.newId(),
        from: w.from,
        to: w.to,
        rows: remaining,
        source: w.source,
        periodConfirmed: w.periodConfirmed,
      );
      _preview = null;
      _note = 'Periksa sisa jadwal dan pilih maksimal delapan baris per persetujuan.';
    });
    await _run(_refresh);
  }

  Future<void> _save() async {
    final w = _workspace;
    if (w == null || _busy) return;
    setState(() {
      _busy = true;
      _committing = true;
      _error = '';
    });
    try {
      if (!w.attempted) {
        final preview = await widget.repository.preview(w);
        widget.repository.prepare(w, preview);
        w.attempted = true;
        if (!await _persist()) {
          w.attempted = false;
          throw const DraftFailure(
            'Tinjauan belum tersimpan. Belum ada jadwal ditambahkan.',
          );
        }
      }
      await widget.repository.apply(w);
      await _persist();
      await _imageStore.clear();
      await widget.assistant.agenda.load();
      if (mounted) {
        setState(() => _images = []);
        _revealSuccess();
      }
    } catch (e) {
      if (e is ImportNeedsReview ||
          e is FirebaseException &&
              [
                'permission-denied',
                'failed-precondition',
                'aborted',
                'invalid-argument',
              ].contains(e.code)) {
        if (!w.applied) {
          w.attempted = false;
          w.plans = [];
        }
      }
      if (mounted) {
        setState(
          () => _error = e is DraftFailure ? e.message : 'Penyimpanan belum terkonfirmasi. Periksa dan coba lagi; operasi yang sama tidak dibuat ulang.',
        );
      }
      await _persist();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _committing = false;
        });
      }
    }
  }

  void _cancelRead() {
    _generation++;
    _cancellation?.cancel();
    setState(() {
      _busy = false;
      _error = 'Pembacaan dibatalkan. Lampiran dan isian masih tersedia.';
    });
  }

  Widget _period() => RumaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Periode jadwal · WIB',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mulai'),
          subtitle: Text(_from ?? 'Pilih tanggal awal'),
          trailing: const RumaIcon('calendar-days'),
          onTap:
              _busy ||
                  _workspace?.attempted == true && _workspace?.applied != true
              ? null
              : () => _date(true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sampai'),
          subtitle: Text(_to ?? 'Pilih akhir semester/periode'),
          trailing: const RumaIcon('calendar-days'),
          onTap:
              _busy ||
                  _workspace?.attempted == true && _workspace?.applied != true
              ? null
              : () => _date(false),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final w = _workspace;
    return PopScope(
      canPop: !_committing,
      child: Scaffold(
        appBar: AppBar(title: const Text('Impor jadwal')),
        body: RumaPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RumaHeading(
                'Jadwalmu, tersusun.',
                'Dari gambar atau Google Calendar. Tinjau sebelum masuk Agenda.',
                compact: true,
              ),
              const SizedBox(height: 16),
              if (_error.isNotEmpty) ...[
                ErrorNotice(_error),
                const SizedBox(height: 12),
              ],
              if (w?.applied == true) ...[
                RumaCard(
                  key: _successKey,
                  color: RumaColors.sage,
                  child: Text(
                    '${w!.resultCount} jadwal diperbarui/ditambahkan. Penyimpanan terkonfirmasi.',
                  ),
                ),
                const SizedBox(height: 12),
                RumaButton(
                  label: 'Lihat Agenda',
                  onPressed: () => Navigator.pop(context, true),
                ),
                if (w.rows.any((r) => !r.included)) ...[
                  const SizedBox(height: 8),
                  RumaButton(
                    label: 'Tinjau jadwal tersisa',
                    secondary: true,
                    onPressed: _busy ? null : _continueRemaining,
                  ),
                ],
                const SizedBox(height: 16),
              ],
              if (w?.attempted != true || w?.applied == true) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('import-source-$_source'),
                  initialValue: _source,
                  decoration: const InputDecoration(labelText: 'Sumber jadwal'),
                  items: const [
                    DropdownMenuItem(
                      value: 'image',
                      child: Text(
                        'Gambar jadwal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'google',
                      child: Text(
                        'Google Calendar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _source = v!),
                ),
                const SizedBox(height: 12),
                _period(),
                const SizedBox(height: 12),
                if (_source == 'image') ...[
                  if (_images.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _images.length; i++)
                          Semantics(
                            label: 'Gambar jadwal ${i + 1}',
                            button: true,
                            child: InkWell(
                              onTap: () => _showSource(i),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _images[i].bytes,
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  RumaButton(
                    label: _images.isEmpty
                        ? 'Pilih gambar jadwal'
                        : 'Ganti gambar',
                    secondary: true,
                    onPressed: _busy ? null : _pick,
                  ),
                  const SizedBox(height: 8),
                  if (_images.isNotEmpty)
                    RumaButton(
                      label: 'Baca gambar dengan Asisten',
                      onPressed: _busy ? null : _extract,
                    ),
                ] else ...[
                  const Text(
                    'Ruma hanya membaca kalender pilihanmu. Perubahan di Ruma tidak mengubah Google Calendar.',
                  ),
                  const SizedBox(height: 8),
                  RumaButton(
                    label: _calendar.account.isEmpty
                        ? 'Hubungkan Google Calendar'
                        : 'Pilih akun Google lain',
                    secondary: true,
                    onPressed: _busy ? null : _connect,
                  ),
                  if (_calendar.account.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_calendar.account),
                  ],
                  if (_calendars.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _calendarId,
                      decoration: const InputDecoration(
                        labelText: 'Kalender sumber',
                      ),
                      items: [
                        for (final c in _calendars)
                          DropdownMenuItem(
                            value: c.id,
                            enabled: c.readable,
                            child: Text(
                              c.readable
                                  ? c.title
                                  : '${c.title} · rincian tidak dapat dibaca',
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _calendarId = v),
                    ),
                    const SizedBox(height: 8),
                    RumaButton(
                      label: 'Ambil jadwal / periksa pembaruan',
                      onPressed:
                          _busy ||
                              _calendarId == null ||
                              _from == null ||
                              _to == null
                          ? null
                          : _loadGoogle,
                    ),
                  ],
                ],
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  _committing
                      ? 'Memeriksa dan menyimpan pilihan…'
                      : 'Menyiapkan tinjauan…',
                ),
                if (!_committing)
                  TextButton(
                    onPressed: _cancelRead,
                    child: const Text('Batalkan pembacaan'),
                  ),
              ],
              if (_note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_note, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (w != null) ...[
                const SizedBox(height: 24),
                Text(w.source, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${w.from}–${w.to} · WIB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  w.applied
                      ? 'Tersimpan'
                      : w.attempted
                      ? 'Hasil penyimpanan perlu diperiksa'
                      : 'Belum disimpan · revisi ${w.revision}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (w.rows.isEmpty)
                  const RumaCard(
                    child: Text(
                      'Belum ada jadwal yang dapat dibaca. Coba gambar lain atau kalender/periode berbeda.',
                    ),
                  ),
                for (final row in w.rows) _rowCard(row),
                if (_preview?.error.isNotEmpty == true) ...[
                  ErrorNotice(_preview!.error),
                  const SizedBox(height: 8),
                ],
                if (!w.locked) ...[
                  TextField(
                    key: const ValueKey('schedule-correction'),
                    controller: _correction,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Koreksi lewat chat',
                      hintText: 'Basis Data pindah Kamis jam 10',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  RumaButton(
                    label: 'Perbarui usulan',
                    secondary: true,
                    onPressed: _busy || w.rows.isEmpty ? null : _correct,
                  ),
                  const SizedBox(height: 8),
                  RumaButton(
                    label: 'Periksa ulang jadwal',
                    secondary: true,
                    onPressed: _busy ? null : () => _run(_refresh),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!w.applied)
                  RumaButton(
                    key: const ValueKey('schedule-import-save'),
                    label: w.attempted
                        ? 'Periksa hasil dan coba lagi'
                        : 'Setujui ${_preview?.writes.length ?? 0} perubahan jadwal',
                    busy: _committing,
                    onPressed:
                        _busy || !w.attempted && _preview?.canSave != true
                        ? null
                        : _save,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowCard(ScheduleRow row) {
    final w = _workspace!;
    ImportPreviewRow? result;
    for (final r in _preview?.rows ?? <ImportPreviewRow>[]) {
      if (r.row.id == row.id) result = r;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                row.title.isEmpty ? 'Nama belum terbaca' : row.title,
                style: const TextStyle(color: RumaColors.ink),
              ),
              subtitle: Text(
                style: const TextStyle(color: RumaColors.muted),
                row.cancelled
                    ? 'Sumber dibatalkan'
                    : '${row.weekly ? (row.weekday == null ? 'Hari belum jelas' : days[row.weekday! - 1]) : row.date ?? 'Tanggal belum jelas'} · ${row.start.isEmpty ? '?' : row.start}–${row.end.isEmpty ? '?' : row.end} WIB${row.weekly ? ' · tiap minggu' : ''}',
              ),
              value: row.included,
              onChanged: _busy || w.locked
                  ? null
                  : (v) {
                      row.included = v ?? false;
                      w.changed();
                      setState(() => _preview = null);
                      unawaited(_run(_refresh));
                    },
            ),
            if (row.exceptions.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${row.exceptions.length} pertemuan khusus dari Google',
                ),
                children: [
                  for (final e in row.exceptions.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e.value['status'] == 'cancelled'
                              ? '${e.key}: dibatalkan'
                              : '${e.key} → ${agendaLocal(DateTime.parse(e.value['startAtUtc'] as String)).toIso8601String().substring(0, 16).replaceAll('T', ' ')} WIB · ${e.value['durationMinutes']} menit',
                        ),
                      ),
                    ),
                ],
              ),
            if (result?.existing != null &&
                ['update', 'delete'].contains(result!.action))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Di Ruma: ${result.existing!.input.title} · ${result.existing!.input.startAtUtc == null ? 'Tanpa jam' : agendaLocal(result.existing!.input.startAtUtc!).toIso8601String().substring(0, 16).replaceAll('T', ' ')} WIB · ${result.existing!.input.durationMinutes} menit',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (result != null)
              Text(
                result.message,
                style: TextStyle(
                  color: result.blocked ? RumaColors.danger : RumaColors.muted,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (!w.locked && !row.cancelled)
                  TextButton(
                    onPressed: _busy ? null : () => _edit(row),
                    child: const Text('Ubah'),
                  ),
                if (row.imageIndex != null && row.imageIndex! < _images.length)
                  TextButton(
                    onPressed: () => _showSource(row.imageIndex!),
                    child: const Text('Lihat gambar sumber'),
                  ),
                if (result?.requiresChoice == true &&
                    result?.existing != null &&
                    !w.locked) ...[
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            row.useSource = true;
                            w.changed();
                            unawaited(_run(_refresh));
                          },
                    child: const Text('Gunakan versi Google'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            row.included = false;
                            w.changed();
                            unawaited(_run(_refresh));
                          },
                    child: const Text('Pertahankan Ruma'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSource(int index) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Gambar sumber ${index + 1}')),
        body: InteractiveViewer(
          minScale: .5,
          maxScale: 6,
          child: Center(child: Image.memory(_images[index].bytes)),
        ),
      ),
    ),
  );
}

class _ScheduleRowEditor extends StatefulWidget {
  const _ScheduleRowEditor({required this.row});
  final ScheduleRow row;
  @override
  State<_ScheduleRowEditor> createState() => _ScheduleRowEditorState();
}

class _ScheduleRowEditorState extends State<_ScheduleRowEditor> {
  late final TextEditingController _title, _location;
  late int? _weekday;
  late String _start, _end;
  String? _date;
  String _error = '';
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.row.title);
    _location = TextEditingController(text: widget.row.location);
    _weekday = widget.row.weekday;
    _date = widget.row.date;
    _start = widget.row.start;
    _end = widget.row.end;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _time(bool start) async {
    final raw = (start ? _start : _end).split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(raw.first) ?? 8,
        minute: raw.length == 2 ? int.tryParse(raw[1]) ?? 0 : 0,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  void _apply() {
    if (_title.text.trim().isEmpty ||
        _title.text.length > 120 ||
        _start.isEmpty ||
        _end.isEmpty ||
        _end.compareTo(_start) <= 0 ||
        widget.row.weekly && _weekday == null ||
        !widget.row.weekly && _date == null) {
      setState(
        () => _error = 'Lengkapi nama, hari, dan jam mulai–selesai yang benar.',
      );
      return;
    }
    final row = widget.row;
    row.title = _title.text.trim();
    row.location = _location.text.trim();
    row.weekday = _weekday;
    row.date = _date;
    row.start = _start;
    row.end = _end;
    row.issue = '';
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ubah usulan jadwal')),
    body: RumaPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RumaHeading(
            'Periksa jadwalnya.',
            'Perubahan ini hanya pada usulan Ruma.',
            compact: true,
          ),
          const SizedBox(height: 16),
          if (_error.isNotEmpty) ...[
            ErrorNotice(_error),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Nama kegiatan / mata kuliah',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.row.weekly) ...[
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'Hari'),
              items: [
                for (var i = 0; i < 7; i++)
                  DropdownMenuItem(
                    value: i + 1,
                    child: Text(_ScheduleImportPageState.days[i]),
                  ),
              ],
              onChanged: (v) => setState(() => _weekday = v),
            ),
            const SizedBox(height: 12),
          ],
          if (!widget.row.weekly)
            ListTile(
              title: const Text('Tanggal kegiatan'),
              subtitle: Text(_date ?? 'Pilih tanggal'),
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_date ?? '') ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null && mounted) {
                  setState(() => _date = dateKey(selected));
                }
              },
            ),
          RumaCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mulai (WIB)'),
                  subtitle: Text(_start.isEmpty ? 'Pilih jam' : _start),
                  onTap: () => _time(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Selesai (WIB)'),
                  subtitle: Text(_end.isEmpty ? 'Pilih jam' : _end),
                  onTap: () => _time(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Ruang / lokasi · opsional',
            ),
          ),
          const SizedBox(height: 16),
          RumaButton(label: 'Terapkan koreksi', onPressed: _apply),
        ],
      ),
    ),
  );
}
