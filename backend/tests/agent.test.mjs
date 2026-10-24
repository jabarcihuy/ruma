import {test} from 'node:test';
import assert from 'node:assert/strict';
import {normalizeDraft} from '../src/agent.mjs';
const source = 'Besok mau beli buku 50 ribu.';
const transaction = {action: 'create_transaction', title: 'Buku', localDate: '2026-10-19', durationMinutes: null,
  amountRupiah: 50000, transactionType: 'expense', categoryId: 'other', transactionStatus: 'actual', sourceQuote: source};
const message = item => ({tool_calls: [{id: 'synthetic-call', type: 'function', function: {name: 'prepare_draft', arguments: JSON.stringify({items: [item]})}}]});
test('future plan cannot become an expense even if model labels it actual today', () => {
  assert.equal(normalizeDraft(message(transaction), source, '2026-10-18').type, 'clarification');
  assert.equal(normalizeDraft(message({...transaction, localDate: '2026-10-18'}), source, '2026-10-18').type, 'clarification');
});
test('actual expense is reviewable, never reported as saved', () => {
  const quote = 'Tadi beli buku 50 ribu.';
  const result = normalizeDraft(message({...transaction, localDate: '2026-10-18', sourceQuote: quote}), quote, '2026-10-18');
  assert.equal(result.type, 'draft_proposal');
  assert.match(result.content, /belum disimpan/);
});
test('free model text cannot make a persistence claim', () => {
  const result = normalizeDraft({content: 'Sudah saya catat dan tersimpan.'}, source, '2026-10-18');
  assert.equal(result.type, 'clarification');
  assert.doesNotMatch(result.content, /catat|simpan/);
});
test('reject invalid money, impossible dates, forged evidence and extra authority', () => {
  for (const change of [{amountRupiah: -1}, {localDate: '2026-02-30'}, {sourceQuote: 'not in message'}, {approved: true}])
    assert.throws(() => normalizeDraft(message({...transaction, ...change}), source, '2026-10-18'));
});
