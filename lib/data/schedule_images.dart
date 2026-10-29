import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'assistant_draft.dart';
import 'schedule_import.dart';

class ScheduleImage {
  const ScheduleImage(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

class ScheduleImages {
  ScheduleImages(this.uid, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final String uid;
  final ImagePicker _picker;
  String get _key => 'ruma.schedule.images.${scheduleHash(uid)}';
  Future<Directory> _directory() async => Directory(
    '${(await getTemporaryDirectory()).path}/ruma-schedule/${scheduleHash(uid)}',
  ).create(recursive: true);

  Future<List<ScheduleImage>> pending() async {
    final prefs = await SharedPreferences.getInstance(),
        dir = await _directory();
    final value = prefs.getString(_key);
    if (value == null) return [];
    try {
      final state = jsonDecode(value) as Map;
      if (DateTime.now().millisecondsSinceEpoch - (state['at'] as int) >
          const Duration(hours: 24).inMilliseconds) {
        await clear();
        return [];
      }
      final names = (state['files'] as List).cast<String>();
      if (names.length > 3 ||
          names.any(
            (n) => !RegExp(r'^image-[0-9]+-[0-9]+\.png$').hasMatch(n),
          )) {
        throw const FormatException();
      }
      final result = <ScheduleImage>[];
      for (final name in names) {
        final file = File('${dir.path}/$name');
        if (!await file.exists()) continue;
        final size = await file.length();
        if (size > 3000000) throw const FormatException();
        result.add(ScheduleImage(await file.readAsBytes(), name));
      }
      return result;
    } catch (_) {
      await clear();
      return [];
    }
  }

  Future<List<ScheduleImage>> pick() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ruma.schedule.pickerOwner', uid);
    final files = await _picker.pickMultiImage(
      limit: 3,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (files.isEmpty) return [];
    return _store(files);
  }

  Future<int> recover() async {
    if (!Platform.isAndroid) return 0;
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString('ruma.schedule.pickerOwner');
    final lost = await _picker.retrieveLostData();
    if (lost.isEmpty || owner != uid || lost.files == null) return 0;
    return (await _store(lost.files!)).length;
  }

  Future<List<ScheduleImage>> _store(List<XFile> files) async {
    if (files.length > 3) {
      throw const DraftFailure('Pilih maksimal tiga gambar jadwal.');
    }
    final images = <ScheduleImage>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < files.length; i++) {
      if (await files[i].length() > 15000000) {
        throw const DraftFailure(
          'Gambar terlalu besar. Potong bagian jadwal atau pilih screenshot.',
        );
      }
      final encoded = await files[i].readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      ui.Image? image;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width * descriptor.height > 40000000) {
          throw const DraftFailure(
            'Dimensi gambar terlalu besar. Pilih bagian jadwal saja.',
          );
        }
        final ratio = math.min(
          1.0,
          2400 / math.max(descriptor.width, descriptor.height),
        );
        codec = await descriptor.instantiateCodec(
          targetWidth: (descriptor.width * ratio).round(),
          targetHeight: (descriptor.height * ratio).round(),
        );
        image = (await codec.getNextFrame()).image;
        // Re-encode pixels: original EXIF/GPS and other file metadata are omitted.
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null || data.lengthInBytes > 3000000) {
          throw const DraftFailure(
            'Gambar masih terlalu besar. Potong bagian jadwal agar tulisan tetap jelas.',
          );
        }
        images.add(
          ScheduleImage(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            'image-$stamp-$i.png',
          ),
        );
      } finally {
        image?.dispose();
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
    }
    if (images.fold<int>(0, (n, i) => n + i.bytes.length) > 8000000) {
      throw const DraftFailure(
        'Total gambar melebihi 8 MB. Pilih lebih sedikit gambar.',
      );
    }
    await clear();
    final dir = await _directory();
    for (final image in images) {
      await File('${dir.path}/${image.name}')
          .writeAsBytes(image.bytes, flush: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'at': DateTime.now().millisecondsSinceEpoch,
        'files': images.map((i) => i.name).toList(),
      }),
    );
    await prefs.remove('ruma.schedule.pickerOwner');
    return images;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    if (prefs.getString('ruma.schedule.pickerOwner') == uid) {
      await prefs.remove('ruma.schedule.pickerOwner');
    }
    final dir = await _directory();
    // Only our sanitized copies are deleted, never a user gallery original.
    await for (final entry in dir.list()) {
      if (entry is File &&
          RegExp(r'/image-[0-9]+-[0-9]+\.png$').hasMatch(entry.path)) {
        await entry.delete();
      }
    }
  }
}
