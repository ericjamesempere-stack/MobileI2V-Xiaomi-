# KARMA ONE — guided interface

The existing storyboard controller, save path, reference import, real remote generation and native MP4 exporter are preserved. `studio_friendly_ui.gd` builds the presentation; `storyboard.gd` retains the workflow.

Three steps replace the original list of technical commands:

1. **Personnage**: choose a photo or reveal a short character-description field, then choose one of six large style tiles.
2. **Histoire**: write a story or insert one of three examples, select a short duration and create the key drawings. An absent reference can be created automatically from the character description.
3. **Mon film**: inspect the sheet, play a timed preview of the existing drawings, explicitly confirm they were reviewed, create MP4, share.

Technical settings, tokens, manual duration/count, imports, merges and legacy tools are retained in a panel closed by default. Generation prevents repeated button actions and step changes while busy. Error and quota messages remain visible in a fixed status area. Completed drawings remain resumable through the existing generator cache.

Validation includes navigation, hidden advanced settings, character/style selection, missing-story/reference messages, disabled export before review, busy guards, exact reference reuse, option persistence and absence of private tokens from project JSON. Rendering snapshots were inspected at 720×1280 using Godot 4.5.2, Xvfb and Mesa. There was no horizontal overflow. These are Linux rendering checks, not physical Android tests.

The APK launcher label is KARMA ONE, version 1.2 / code 3, with a new icon. The application package and Godot user-data name are unchanged to preserve existing project storage. Signature continuity must be checked against the preceding APK's CI certificate.

This interface does not change the limits of image generation: public GPU quotas, possible character drift, unverified styles and the need for intermediate drawings remain. A preview of existing drawings is not a guarantee of fluid animation.
