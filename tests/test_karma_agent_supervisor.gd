extends SceneTree
# Run: godot --headless --path . --script res://tests/test_karma_agent_supervisor.gd
var failures: Array[String] = []
func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    var supervisor: RefCounted = load("res://scripts/karma_agent_supervisor.gd").new()
    expect(not supervisor.check_engine({"id": "local", "reachable": true, "model_loaded": true}).get("ok", false), "unverified model accepted")
    expect(not supervisor.check_engine({"id": "local", "reachable": true, "model_loaded": true, "image_inference_verified": true}).get("ok", false), "unverified reference conditioning accepted")
    expect(supervisor.check_engine({"id": "local", "reachable": true, "model_loaded": true, "image_inference_verified": true, "reference_conditioning_verified": true}).get("ok", false), "verified engine rejected")
    var session: Dictionary = supervisor.new_session("test")
    expect(not supervisor.may_export(session, "hash").get("ok", false), "export allowed before approval")
    expect(not supervisor.advance(session, "images_ready", {"ok": true, "real_image_count": 8, "pixel_files_verified": true}).get("ok", false), "stage skipped")
    session = supervisor.advance(session, "poses_ready", {"ok": true, "pose_count": 8})
    expect(session.get("ok", false), "poses not accepted")
    expect(not supervisor.advance(session, "images_ready", {"ok": true, "real_image_count": 8}).get("ok", false), "fake images accepted")
    session = supervisor.advance(session, "images_ready", {"ok": true, "real_image_count": 8, "pixel_files_verified": true})
    session = supervisor.advance(session, "quality_checked", {"ok": true, "all_frames_checked": true})
    expect(not supervisor.advance(session, "human_approved", {"ok": true, "fingerprint": "hash"}).get("ok", false), "implicit approval accepted")
    session = supervisor.advance(session, "human_approved", {"ok": true, "fingerprint": "hash", "explicit_user_approval": true})
    expect(supervisor.may_export(session, "hash").get("ok", false), "valid approval rejected")
    expect(not supervisor.may_export(session, "changed").get("ok", false), "stale approval accepted")
    expect(not supervisor.advance(session, "video_verified", {"ok": true, "mp4_decoded": false, "sha256": "a".repeat(64)}).get("ok", false), "undecoded video accepted")
    session = supervisor.advance(session, "video_verified", {"ok": true, "mp4_decoded": true, "sha256": "a".repeat(64)})
    expect(session.get("ok", false), "verified video rejected")
    if failures.is_empty():
        print("PASS karma_agent_supervisor: 12 assertions")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
