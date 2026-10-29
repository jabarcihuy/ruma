import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/agenda.dart';
import '../../data/recurrence.dart';
import '../../data/finance.dart' show dateKey;
import '../../data/agenda_repository.dart';
import '../../ui/components.dart';

String dayLabel(BuildContext context, DateTime day) =>
    MaterialLocalizations.of(context).formatFullDate(day);
String clockLabel(BuildContext context, DateTime utc) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(agendaLocal(utc)),
      alwaysUse24HourFormat: true,
    );

class AgendaFormPage extends StatefulWidget {
  const AgendaFormPage({
    super.key,
    required this.store,
    this.existing,
    this.initialDay,
    this.onDraftChanged,
    this.kind = 'task',
    this.scope = 'one',
  });
  final AgendaStore store;
  final AgendaItem? existing;
  final DateTime? initialDay;
  final String kind, scope;
  final ValueChanged<AgendaInput>? onDraftChanged;
  @override
  State<AgendaFormPage> createState() => _AgendaFormPageState();
}

class _AgendaFormPageState extends State<AgendaFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description, _duration;
  late final String _id;
  late String _kind, _priority, _status;
  DateTime? _start, _deadline;
  bool _weekly = false;
  String? _until;
  bool _dirty = false, _leaving = false;
  AgendaMutation? _pending;
  String? _error;
  @override
  void initState() {
    super.initState();
    final input = widget.existing?.input;
    _kind = input?.kind ?? widget.kind;
    _priority = input?.priority ?? 'normal';
    _status = input?.status ?? 'planned';
    _title = TextEditingController(text: input?.title ?? '');
    _description = TextEditingController(text: input?.description ?? '');
    _duration = TextEditingController(
      text: '${input?.durationMinutes ?? widget.store.defaultDurationMinutes}',
    );
    _weekly = input?.recurrence != null;
    _until = input?.recurrence?['untilLocalDate'] as String?;
    _start = input?.startAtUtc;
    _deadline = input?.deadlineAtUtc;
    _id = widget.existing?.id ?? widget.store.repository.newId();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {
      _dirty = true;
      _error = null;
    });
  }

  Future<void> _back() async {
    if (widget.store.saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => RumaDialog(
          title: const Text('Tinggalkan isian ini?'),
          content: const Text('Perubahan belum disimpan.'),
          actions: [
            RumaButton(
              label: 'Lanjut mengedit',
              secondary: true,
              onPressed: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 8),
            RumaButton(
              label: 'Buang perubahan',
              destructive: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _leaving = true);
    if (mounted) Navigator.pop(context);
  }

  Future<DateTime?> _pickDateTime(DateTime? original) async {
    final now = agendaLocal(DateTime.now().toUtc());
    final day = widget.initialDay ?? now;
    final initial = original == null
        ? DateTime(day.year, day.month, day.day, now.hour, now.minute)
        : agendaLocal(original);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return time == null ? null : agendaUtc(date, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final input = AgendaInput(
      title: _title.text.trim(),
      description: _description.text,
      kind: _kind,
      durationMinutes: int.parse(_duration.text),
      startAtUtc: _start,
      deadlineAtUtc: _deadline,
      priority: _priority,
      status: _status,
      recurrence: _weekly && _start != null
          ? {
              ...?widget.existing?.input.recurrence,
              ...weeklyPattern(_start!, until: _until),
              if (widget.existing?.input.recurrence != null)
                ...widget.existing!.input.recurrence!,
              'untilLocalDate': _until,
            }
          : null,
    );
    final invalid = input.validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    if (widget.onDraftChanged != null) {
      widget.onDraftChanged!(input);
      setState(() => _leaving = true);
      Navigator.pop(context, true);
      return;
    }
    final candidate = AgendaMutation(
      operationId: _pending?.operationId ?? widget.store.repository.newId(),
      scope: widget.scope,
      id: _id,
      input: input,
      originalVersion: widget.existing?.version,
    );
    // A retry of unchanged input reuses the operation ID and entity ID.
    _pending = _pending?.requestKey == candidate.requestKey
        ? candidate
        : AgendaMutation(
            operationId: widget.store.repository.newId(),
            scope: widget.scope,
            id: _id,
            input: input,
            originalVersion: widget.existing?.version,
          );
    final ok = await widget.store.save(_pending!);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = widget.store.error);
      return;
    }
    setState(() => _leaving = true);
    Navigator.pop(context, true);
  }

  Widget _picker({
    required String label,
    required String value,
    required VoidCallback? onTap,
    required String id,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Material(
          color: RumaColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: ValueKey(id),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: RumaColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(value),
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final busy = widget.store.saving;
      return PopScope(
        canPop: _leaving || (!_dirty && !busy),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_kind == 'class' ? 'Jadwal kuliah' : 'Kegiatan'),
            leading: IconButton(
              tooltip: 'Kembali',
              onPressed: busy ? null : _back,
              icon: const RumaIcon('arrow-left', color: RumaColors.accent),
            ),
          ),
          body: RumaPageBody(
            child: Form(
              key: _form,
              onChanged: _changed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RumaHeading(
                    widget.existing != null
                        ? 'Edit kegiatan'
                        : _kind == 'class'
                        ? 'Tambah jadwal'
                        : 'Kegiatan baru',
                    null,
                    compact: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('agenda-title'),
                    controller: _title,
                    enabled: !busy,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: _kind == 'class'
                          ? 'Nama jadwal *'
                          : 'Nama kegiatan *',
                    ),
                    validator: (s) => s == null || s.trim().isEmpty
                        ? 'Isi nama kegiatan.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_kind == 'task') ...[
                    _picker(
                      label: 'Deadline (opsional)',
                      value: _deadline == null
                          ? 'Belum diatur'
                          : '${dayLabel(context, agendaLocal(_deadline!))} · ${clockLabel(context, _deadline!)} WIB',
                      id: 'agenda-deadline',
                      onTap: busy
                          ? null
                          : () async {
                              final date = await _pickDateTime(_deadline);
                              if (date != null && mounted) {
                                _deadline = date;
                                _changed();
                              }
                            },
                    ),
                    if (_deadline != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                _deadline = null;
                                _changed();
                              },
                        child: const Text('Hapus deadline'),
                      ),
                  ],
                  _picker(
                    label: _kind == 'class'
                        ? 'Tanggal & jam mulai (WIB) *'
                        : 'Waktu kegiatan (WIB)',
                    value: _start == null
                        ? 'Belum dijadwalkan'
                        : '${dayLabel(context, agendaLocal(_start!))} · ${clockLabel(context, _start!)} WIB',
                    id: 'agenda-start',
                    onTap: busy
                        ? null
                        : () async {
                            final date = await _pickDateTime(_start);
                            if (date != null && mounted) {
                              _start = date;
                              _changed();
                            }
                          },
                  ),
                  if (_kind == 'task' && _start != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              _start = null;
                              _changed();
                            },
                      child: const Text('Simpan tanpa waktu'),
                    ),
                  if (_kind == 'class' &&
                      widget.onDraftChanged == null &&
                      occurrenceKey(_id) == null) ...[
                    SwitchListTile(
                      key: const ValueKey('agenda-weekly'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ulangi setiap minggu'),
                      value: _weekly,
                      onChanged: busy
                          ? null
                          : (v) {
                              _weekly = v;
                              _changed();
                            },
                    ),
                    if (_weekly) ...[
                      TextButton(
                        key: const ValueKey('agenda-repeat-until'),
                        onPressed: busy
                            ? null
                            : () async {
                                final initial = agendaLocal(
                                  _start ?? DateTime.now().toUtc(),
                                );
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _until == null
                                      ? initial.add(const Duration(days: 112))
                                      : DateTime.parse(_until!),
                                  firstDate: DateTime(
                                    initial.year,
                                    initial.month,
                                    initial.day,
                                  ),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null && mounted) {
                                  _until = dateKey(d);
                                  _changed();
                                }
                              },
                        child: Text(
                          _until == null
                              ? 'Tanpa tanggal akhir'
                              : 'Berakhir $_until',
                        ),
                      ),
                      if (_until != null)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () {
                                  _until = null;
                                  _changed();
                                },
                          child: const Text('Tanpa tanggal akhir'),
                        ),
                    ],
                  ],
                  if (widget.scope == 'future')
                    const Text('Mulai pertemuan ini; pengecualian lain tetap.'),
                  TextFormField(
                    key: const ValueKey('agenda-duration'),
                    controller: _duration,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Durasi (menit) *',
                    ),
                    validator: (s) {
                      final n = int.tryParse(s ?? '');
                      return n == null || n < 5 || n > 720
                          ? 'Isi durasi 5–720 menit.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  RumaDurationChoices(
                    controller: _duration,
                    enabled: !busy,
                    onChanged: _changed,
                  ),
                  if (_start != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Selesai ${clockLabel(context, _start!.add(Duration(minutes: int.tryParse(_duration.text) ?? 60)))} WIB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Material(
                    color: RumaColors.line,
                    borderRadius: BorderRadius.circular(16),
                    child: ExpansionTile(
                      title: const Text('Opsi lainnya'),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Prioritas',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('Rendah'),
                            ),
                            DropdownMenuItem(
                              value: 'normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('Tinggi'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) {
                                  _priority = value!;
                                  _changed();
                                },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('agenda-description'),
                          controller: _description,
                          enabled: !busy,
                          maxLength: 1000,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Catatan (opsional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ErrorNotice(_error!),
                    ),
                  const SizedBox(height: 16),
                  RumaButton(
                    key: const ValueKey('agenda-save'),
                    label: widget.onDraftChanged != null
                        ? 'Gunakan dalam draf'
                        : busy
                        ? 'Menyimpan…'
                        : widget.existing != null
                        ? 'Simpan perubahan'
                        : _kind == 'class'
                        ? 'Simpan jadwal kuliah'
                        : _start == null
                        ? 'Simpan tanpa waktu'
                        : 'Simpan kegiatan',
                    busy: busy,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
