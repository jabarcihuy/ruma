import 'agenda.dart';
import 'assistant_draft.dart';

// Only conversational replies enter provider context. Verified ledger/read
// output stays on the device; old snapshots without a kind are excluded.
List<Map<String, String>> conversationMessages(
  List<Map<String, String>> history,
  String message,
) {
  final turns = history.skip(history.length > 8 ? history.length - 8 : 0);
  final rows = <Map<String, String>>[];
  for (final turn in turns) {
    if (turn['message']?.trim().isNotEmpty == true) {
      rows.add({'role': 'user', 'content': turn['message']!});
    }
    if (['answer', 'clarification'].contains(turn['kind']) &&
        turn['reply']?.trim().isNotEmpty == true &&
        turn['reply']!.length <= 4000) {
      rows.add({'role': 'assistant', 'content': turn['reply']!});
    }
  }
  rows.add({'role': 'user', 'content': message});
  while (rows.length > 17 ||
      rows.fold<int>(0, (n, m) => n + m['content']!.length) > 12000) {
    rows.removeAt(0);
  }
  return rows;
}

List<Map<String, dynamic>> proposalContext(AssistantDraft? draft) =>
    draft == null || draft.applied
    ? []
    : draft.items.where((e) => e.included).map((e) {
        String? local(DateTime? value) => value == null
            ? null
            : agendaLocal(value).toIso8601String().substring(0, 16);
        return <String, dynamic>{
          'action': e.agenda != null ? 'create_agenda' : 'create_transaction',
          'title': e.agenda?.title ?? e.money!.description,
          'localDate': e.localDate,
          'durationMinutes': e.agenda?.durationMinutes,
          'startLocal': local(e.agenda?.startAtUtc),
          'deadlineLocal': local(e.agenda?.deadlineAtUtc),
          'amountRupiah': e.money?.amountRupiah,
          'transactionType': e.money?.type,
          'categoryId': e.money?.categoryId,
          'transactionStatus': e.money == null ? null : 'actual',
          'sourceQuote': e.quote,
        };
      }).toList();

String conversationSource(
  List<Map<String, String>> messages,
  List<Map<String, dynamic>> proposal,
) => [
  ...messages.where((m) => m['role'] == 'user').map((m) => m['content']!),
  ...proposal.map((m) => m['sourceQuote'] as String),
].join(' ');
