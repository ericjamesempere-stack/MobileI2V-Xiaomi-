# V53 — reference import, subject fidelity and reviewed storyboard

## Fixes

- Android image selection now uses the native document picker and ContentResolver/ImageDecoder. The selected URI is converted on a worker thread to a bounded PNG in app-private storage, then imported into the existing project. A direct FileAccess read of content:// is no longer the primary Android import route. PNG/JPEG/HEIF support depends on the Android decoder; HEIF and the actual Xiaomi picker are not asserted as tested.
- Every successful import is displayed, added to the saved reference board, and remains available after loading the project.
- Contact-sheet thumbnails duplicate their source Image before resizing it. A new integration test exposed source-image mutation in the dummy renderer; full-resolution reference pixels are now preserved.
- Text generation no longer adds a human body and a neutral standing pose to every subject. The literal user description is preserved. Objects must remain the requested object unless anthropomorphic features are explicitly requested. Source generation requests 1024×1024. The real banana generation attempt was quota-blocked; this is not a visual validation of a banana output.
- The application's entry scene now directly opens the existing storyboard controller. Legacy placeholder humans and the obsolete reader are no longer behind the studio or exposed as a normal generation route. The old source remains in the repository.

## Required workflow

KARMA ONE coordinates the existing specialized modules: scenario timing, pose instructions, real image generation, technical checks, disk recovery and video. These are deterministic application modules, not independent LLM agents. `karma_studio_session.gd` records their actual stages in `karma_agents.json`.

The visible workflow is image + directions → generated drawings → full-resolution review → explicit user approval → MP4. The enlarged reviewer supports previous/next, keep, reject and regenerate one drawing. A rejected drawing blocks approval. Changes to image bytes after approval invalidate the review fingerprint. Legacy auto-export state is forced off; the central video entry point checks approval even if a legacy tool calls it. No generative service error is replaced by a generic procedural character.

The quality module rejects technically blank/too-small outputs and records image checks. It does not prove subject identity, artistic quality or physical motion. User review is still required.

## Evidence and limits

Godot integration tests check a local imported image remains visible and saved, its original pixels are not destroyed by thumbnail generation, the subject prompt does not force a human figure, import/old accepted flags cannot bypass user review, rejected drawings block approval, file changes invalidate approval, and the orchestration journal waits for human approval.

Native Android framework tests cover a content:// photo provider, a readable PNG output and bounded decoding of a large camera image. These tests use Robolectric and are distinct from an actual Xiaomi gallery test. Compilation and native test results must be checked before delivery.

The phone's real gallery, HEIF examples, an actual generated banana, a human-face sequence and a complete high-quality long video remain device/model acceptance tests. Free inference quotas and external API availability remain unchanged.
