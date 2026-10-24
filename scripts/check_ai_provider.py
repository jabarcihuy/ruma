"""Bounded NaraRouter compatibility check; synthetic data, no database writes.

Default: offline self-check only. --live makes at most one catalog request and
five model requests, without retries. Credentials are never command arguments.
"""

import json
from datetime import datetime
from zoneinfo import ZoneInfo
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs/qa/nararouter-check.json"
MODEL = "glm-5.3-flash"
BASE = "https://router.bynara.id/v1"


def validate_draft(args):
    if not isinstance(args, dict) or set(args) != {"items"}:
        return False
    items = args.get("items")
    if not isinstance(items, list) or len(items) != 4:
        return False
    agenda, expenses = [], []
    for item in items:
        fields = {"action", "title", "localDate", "durationMinutes", "amountRupiah", "transactionType", "categoryId"}
        if not isinstance(item, dict) or set(item) != fields or not isinstance(item.get("title"), str) or not item["title"].strip():
            return False
        if item.get("action") == "create_agenda":
            if item.get("localDate") != "2026-10-19" or type(item.get("durationMinutes")) is not int:
                return False
            if any(item.get(k) is not None for k in ("amountRupiah", "transactionType", "categoryId")):
                return False
            if (item["durationMinutes"] == 60 and "laporan" not in item["title"].lower()) or (item["durationMinutes"] == 30 and "jurnal" not in item["title"].lower()):
                return False
            agenda.append(item["durationMinutes"])
        elif item.get("action") == "create_transaction":
            if item.get("localDate") != "2026-10-18" or type(item.get("amountRupiah")) is not int:
                return False
            if item.get("transactionType") != "expense" or item.get("durationMinutes") is not None:
                return False
            expenses.append((item["amountRupiah"], item.get("categoryId")))
        else:
            return False
    return sorted(agenda) == [30, 60] and sorted(expenses) == [(15000, "other"), (18000, "food")]


def self_check():
    items = [
        {"action": "create_agenda", "title": "Revisi laporan", "localDate": "2026-10-19", "durationMinutes": 60},
        {"action": "create_agenda", "title": "Baca jurnal", "localDate": "2026-10-19", "durationMinutes": 30},
        {"action": "create_transaction", "title": "Makan", "localDate": "2026-10-18", "amountRupiah": 18000, "transactionType": "expense", "categoryId": "food"},
        {"action": "create_transaction", "title": "Cetak", "localDate": "2026-10-18", "amountRupiah": 15000, "transactionType": "expense", "categoryId": "other"},
    ]
    for item in items:
        for field in ("durationMinutes", "amountRupiah", "transactionType", "categoryId"):
            item.setdefault(field, None)
    assert validate_draft({"items": items})
    assert not validate_draft({"items": items[:-1]})
    bad = json.loads(json.dumps(items))
    bad[2]["amountRupiah"] = -18000
    assert not validate_draft({"items": bad})
    bad = json.loads(json.dumps(items))
    bad[0]["ownerUid"] = "unexpected"
    assert not validate_draft({"items": bad})
    assert not validate_draft([])
    bad = json.loads(json.dumps(items))
    bad[0]["durationMinutes"] = True
    assert not validate_draft({"items": bad})


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Do not forward the Authorization header to another URL.


def live_check(minimal_resume=False, future_only=False):
    key = next((line.split("=", 1)[1].strip().strip("\"'") for line in (ROOT / ".local/ai.env").read_text().splitlines() if line.startswith("NARAROUTER_API_KEY=")), "")
    if not key.startswith("sk-nry-") or any(c.isspace() for c in key):
        raise ValueError("Local provider key is missing or malformed")
    report = {"date": datetime.now(ZoneInfo("Asia/Jakarta")).date().isoformat(), "provider": "NaraRouter", "requestedModel": MODEL, "syntheticDataOnly": True, "databaseWrites": 0, "modelRequests": 0, "tests": [], "scope": "Direct provider compatibility only; not a deployed proxy or app evaluation"}
    report["checkedAtUtc"] = datetime.now(ZoneInfo("UTC")).isoformat()
    report["payloadProfile"] = "minimal model/messages/tools; no optional generation settings" if minimal_resume else "explicit generation settings"
    opener = urllib.request.build_opener(NoRedirect())

    def clean(value):
        encoded = json.dumps(value, ensure_ascii=False).replace(key, "[REDACTED]")
        return json.loads(re.sub(r"sk-nry-[A-Za-z0-9_-]+", "[REDACTED]", encoded))

    def save():
        REPORT.write_text(json.dumps(clean(report), ensure_ascii=False, indent=2) + "\n")

    def request(name, payload=None):
        if payload is not None:
            if report["modelRequests"] >= 5:
                raise ValueError("Model request cap reached")
            report["modelRequests"] += 1
        url = BASE + ("/models" if payload is None else "/chat/completions")
        req = urllib.request.Request(url, data=None if payload is None else json.dumps(payload).encode(), headers={"Authorization": "Bearer " + key, "Content-Type": "application/json", "User-Agent": "Ruma-Compatibility-Check/1"})
        entry = {"name": name, "passed": False}
        report["tests"].append(entry)
        started = time.monotonic()
        try:
            with opener.open(req, timeout=45) as response:
                entry["httpStatus"] = response.status
                raw = response.read(2_000_001)
            if len(raw) > 2_000_000:
                raise ValueError("Response exceeds check limit")
            data = json.loads(raw)
            if not isinstance(data, dict):
                raise ValueError("Response is not a JSON object")
            if payload is not None:
                entry["responseModel"] = clean(data.get("model"))
                entry["usage"] = {k: v for k, v in data.get("usage", {}).items() if k in ("prompt_tokens", "completion_tokens", "total_tokens") and type(v) is int}
                entry["finishReason"] = data.get("choices", [{}])[0].get("finish_reason")
            return data, entry
        except urllib.error.HTTPError as error:
            entry["httpStatus"] = error.code
            try:
                body = json.loads(error.read(2000))
                detail = body.get("error", {}) if isinstance(body, dict) else "Unexpected error response format"
                entry["error"] = clean(str(detail.get("message", detail) if isinstance(detail, dict) else detail)[:400])
            except (ValueError, OSError):
                entry["error"] = "Provider rejected request; raw response omitted"
            return None, entry
        except Exception as error:
            entry["error"] = type(error).__name__
            return None, entry
        finally:
            entry["latencyMs"] = round((time.monotonic() - started) * 1000)
            save()

    def chat(name, messages, tools=None, choice=None, max_tokens=512):
        body = {"model": MODEL, "messages": messages}
        if not minimal_resume:
            body.update({"stream": False, "reasoning_effort": "none", "max_tokens": max_tokens})
        if tools is not None:
            body["tools"] = tools
        if choice is not None and not minimal_resume:
            body["tool_choice"] = choice
        return request(name, body)

    def message(data):
        if not isinstance(data, dict):
            return {}
        choices = data.get("choices")
        result = choices[0].get("message", {}) if isinstance(choices, list) and choices and isinstance(choices[0], dict) else {}
        return result if isinstance(result, dict) else {}

    if not future_only:
        if minimal_resume:
            baseline = json.loads((ROOT / "docs/qa/nararouter-minimal-probe.json").read_text())
            catalog, plain = baseline["tests"]
            if baseline["model"] != MODEL or catalog.get("modelMetadata", {}).get("id") != MODEL or plain.get("passed") is not True:
                raise ValueError("A matching successful minimal probe is required")
            report["tests"] = [{"name": "model_catalog", "passed": True, "httpStatus": catalog["httpStatus"], "latencyMs": catalog["latencyMs"], "exactModelListed": True}, {"name": "plain_message", "passed": True, "httpStatus": plain["httpStatus"], "latencyMs": plain["latencyMs"], "usage": plain.get("usage", {}), "evidence": "nararouter-minimal-probe.json; reused, not resent"}]
            report["modelRequests"] = 1
            report["reusedBaselineModelRequests"] = 1
            save()
        else:
            catalog, test = request("model_catalog")
            if catalog is not None:
                test["exactModelListed"] = any(x.get("id") == MODEL for x in catalog.get("data", []) if isinstance(x, dict))
                test["passed"] = test["exactModelListed"]
            if catalog is None or not test.get("passed"):
                save()
                return report

            data, test = chat("plain_message", [{"role": "user", "content": "Balas persis RUMA_OK, tanpa teks lain."}])
            test["passed"] = isinstance(message(data).get("content"), str) and message(data)["content"].strip() == "RUMA_OK"
            if not test["passed"]:
                test["visibleReply"] = clean(str(message(data).get("content", ""))[:200])
                save()
                return report

        summary_tool = {"type": "function", "function": {"name": "get_money_summary", "description": "Baca ringkasan keuangan bulan pilihan pengguna.", "parameters": {"type": "object", "properties": {"month": {"type": "string", "enum": ["2026-10"]}}, "required": ["month"], "additionalProperties": False}}}
        turns = [{"role": "system", "content": "Kamu asisten Ruma. Gunakan tool untuk membaca angka uang. Jangan mengarang. Jawab dalam bahasa Indonesia."}, {"role": "user", "content": "Berapa sisa anggaran Oktober 2026?"}]
        data, test = chat("function_call_arguments", turns, [summary_tool], {"type": "function", "function": {"name": "get_money_summary"}})
        assistant = message(data)
        calls = assistant.get("tool_calls") or []
        try:
            test["passed"] = len(calls) == 1 and bool(calls[0]["id"]) and calls[0]["type"] == "function" and calls[0]["function"]["name"] == "get_money_summary" and json.loads(calls[0]["function"]["arguments"]) == {"month": "2026-10"}
        except (KeyError, TypeError, ValueError):
            test["passed"] = False
        if not test["passed"]:
            test["replyShape"] = {"hasToolCalls": bool(calls), "messageFields": list(assistant)}
            save()
            return report
        turns.append({"role": "assistant", "content": assistant.get("content"), "tool_calls": calls})
        turns.append({"role": "tool", "tool_call_id": calls[0]["id"], "content": json.dumps({"month": "2026-10", "budgetRupiah": 1500000, "expenseRupiah": 1180000, "remainingBudgetRupiah": 320000, "synthetic": True})})
        data, test = chat("tool_result_round_trip", turns, [summary_tool], "none")
        reply = message(data).get("content") or ""
        test["passed"] = bool(re.search(r"320[.,\s]?000|320\s*ribu", reply, re.I)) and not message(data).get("tool_calls")
        test["reply"] = clean(reply[:500])
        save()

    properties = {"action": {"type": "string", "enum": ["create_agenda", "create_transaction"]}, "title": {"type": "string"}, "localDate": {"type": "string"}, "durationMinutes": {"type": ["integer", "null"]}, "amountRupiah": {"type": ["integer", "null"]}, "transactionType": {"enum": ["expense", None]}, "categoryId": {"enum": ["food", "other", None]}}
    draft_tool = {"type": "function", "function": {"name": "prepare_draft", "description": "Siapkan draf agenda dan transaksi aktual; tidak menyimpan atau mengubah database.", "parameters": {"type": "object", "properties": {"items": {"type": "array", "items": {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}}}, "required": ["items"], "additionalProperties": False}}}
    system = "Kamu agent Ruma. Waktu acuan 18 Oktober 2026 pukul 10.00 Asia/Jakarta. Gunakan prepare_draft untuk mengusulkan data yang diminta, bukan menyimpan. Catat hanya transaksi uang yang sudah terjadi. Rencana belanja masa depan memerlukan klarifikasi, tidak boleh menjadi pengeluaran aktual. Durasi dalam menit dan nominal integer rupiah. Kategori makan food, cetak other. Field yang tidak berlaku wajib null. Agenda yang belum diperiksa slotnya belum mendapat waktu. Jangan pernah mengaku sudah menyimpan."
    if not future_only:
        user = json.loads((ROOT / "docs/qa/demo-fixture.json").read_text())["message"]
        data, test = chat("combined_draft_extraction", [{"role": "system", "content": system}, {"role": "user", "content": user}], [draft_tool], "auto", 1200)
        calls = message(data).get("tool_calls") or []
        try:
            args = json.loads(calls[0]["function"]["arguments"])
            test["passed"] = len(calls) == 1 and bool(calls[0]["id"]) and calls[0]["type"] == "function" and calls[0]["function"]["name"] == "prepare_draft" and validate_draft(args)
            test["draft"] = clean(args)
        except (IndexError, KeyError, TypeError, ValueError):
            test["passed"] = False
            test["replyShape"] = {"hasToolCalls": bool(calls), "messageFields": list(message(data))}
        save()
        if data is None:
            return report

    data, test = chat("future_purchase_is_not_actual_expense", [{"role": "system", "content": system}, {"role": "user", "content": "Besok mau beli buku 50 ribu."}], [draft_tool], "auto")
    reply = message(data).get("content") or ""
    test["passed"] = data is not None and not message(data).get("tool_calls") and bool(reply.strip())
    test["reply"] = clean(reply[:700])
    test["toolCalls"] = clean(message(data).get("tool_calls") or [])
    test["limitation"] = "No mutation tool call is checked automatically; wording requires review. One sample is not a reliability estimate."
    save()
    return report


if __name__ == "__main__":
    self_check()
    if "--live" not in sys.argv:
        print("Offline validator self-check passed. --live performs bounded paid/provider-quota requests.")
    else:
        future_only = "--future-only" in sys.argv
        if future_only:
            REPORT = ROOT / "docs/qa/nararouter-future-diagnostic.json"
        result = live_check(minimal_resume="--minimal-resume" in sys.argv or future_only, future_only=future_only)
        result["overallPassed"] = len(result["tests"]) == (1 if future_only else 6) and all(x["passed"] for x in result["tests"])
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({"report": str(REPORT.relative_to(ROOT)), "modelRequests": result["modelRequests"], "results": [{"name": x["name"], "passed": x["passed"], "httpStatus": x.get("httpStatus"), "latencyMs": x.get("latencyMs")} for x in result["tests"]]}, ensure_ascii=False, indent=2))
        sys.exit(0 if result["overallPassed"] else 1)
