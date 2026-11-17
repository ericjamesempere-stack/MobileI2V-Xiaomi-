extends RefCounted
# Private technical events only. Never record prompts, pictures, paths or tokens.
# The journal is authoritative: a corrupt/truncated event blocks new model calls.
const LIMIT := 2
var journal: String = "user://karma_autopilot/technical_memory.jsonl"
var events: Array = []
var last_hash: String = ""
var valid: bool = true

func _reload() -> bool:
    events.clear()
    last_hash = ""
    valid = true
    if not FileAccess.file_exists(journal):
        return true
    var file := FileAccess.open(journal, FileAccess.READ)
    if file == null:
        valid = false
        return false
    while file.get_position() < file.get_length():
        var line: String = file.get_line()
        var parsed := JSON.new()
        if line.is_empty() or parsed.parse(line) != OK or not parsed.data is Dictionary:
            valid = false
            break
        var row: Dictionary = parsed.data
        var digest: String = str(row.get("event_sha", ""))
        row.erase("event_sha")
        if row.get("previous", "") != last_hash or digest != JSON.stringify(row).sha256_text():
            valid = false
            break
        events.append(row)
        last_hash = digest
    file.close()
    return valid

func _append(row: Dictionary) -> bool:
    if not valid or DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(journal.get_base_dir())) != OK:
        return false
    row["previous"] = last_hash
    row["event_sha"] = JSON.stringify(row).sha256_text()
    var file := FileAccess.open(journal, FileAccess.READ_WRITE if FileAccess.file_exists(journal) else FileAccess.WRITE)
    if file == null:
        return false
    file.seek_end()
    file.store_line(JSON.stringify(row))
    file.flush()
    var ok: bool = file.get_error() == OK
    file.close()
    if ok:
        last_hash = row["event_sha"]
        var entry: Dictionary = row.duplicate()
        entry.erase("event_sha")
        events.append(entry)
    return ok

func begin(input_sha: String) -> Dictionary:
    if not _reload():
        return {"ok": false, "error": "technical_memory_corrupt_or_unreadable"}
    var failures: Dictionary = {}
    var pending: Dictionary = {}
    for row in events:
        if row.get("input_sha", "") != input_sha:
            continue
        if row.get("event", "") == "start":
            pending[str(row["id"])] = true
        elif row.get("event", "") == "result":
            pending.erase(str(row["id"]))
            if row.get("status", "") == "FAIL":
                var signature: String = str(row["failure_sha"])
                failures[signature] = int(failures.get(signature, 0)) + 1
    if pending.size() >= LIMIT:
        return {"ok": false, "error": "autopilot_interrupted_attempt_budget_exhausted"}
    for count in failures.values():
        if int(count) >= LIMIT:
            return {"ok": false, "error": "autopilot_failure_budget_exhausted"}
    var id: String = (input_sha + str(Time.get_ticks_usec()) + str(randi())).sha256_text()
    if not _append({"event": "start", "id": id, "input_sha": input_sha}):
        return {"ok": false, "error": "technical_memory_write_failed"}
    return {"ok": true, "id": id, "input_sha": input_sha}

func finish(ticket: Dictionary, result: Dictionary) -> bool:
    if not _reload():
        return false
    var open: bool = false
    for row in events:
        if row.get("id", "") == ticket.get("id", ""):
            open = row.get("event", "") == "start"
    if not open:
        return false
    var detail: Dictionary = result.get("detail", {})
    var quality: Dictionary = result.get("quality", {})
    var message: String = str(result.get("error", detail.get("error", quality.get("error", ""))))
    var stage: String = str(result.get("stage", "pipeline"))
    var passed: bool = result.get("ok", false) and result.get("quality", {}).get("fidelity_verified", false) and result.get("intermediate_review", {}).get("fidelity_verified", false)
    # Available candidates are progress, not a failed operation. They remain
    # unapproved and the runtime review gate handles sequence completeness.
    var intermediate_review: Dictionary = result.get("intermediate_review", {})
    var progress_only: bool = result.get("intermediates", {}).get("ok", false) and intermediate_review.get("ok", false) and intermediate_review.get("failed", []).is_empty() and not intermediate_review.get("pending", []).is_empty()
    if not intermediate_review.get("failed", []).is_empty():
        message = "intermediate_fidelity_rejected"
    var status: String = "PASS" if passed else ("NOT_TESTED" if progress_only and message.is_empty() else "FAIL")
    return _append({"event": "result", "id": ticket["id"], "input_sha": ticket["input_sha"], "status": status,
        "stage_sha": stage.sha256_text(), "failure_sha": (stage + ":" + message).sha256_text() if status == "FAIL" else ""})
