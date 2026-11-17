"""V55 regression checks: text prompts must use real pixels and existing review gates."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class UniversalTextEntryContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pipeline = (ROOT / "scripts/universal_board_pipeline.gd").read_text(encoding="utf-8")
        cls.storyboard = (ROOT / "scripts/storyboard.gd").read_text(encoding="utf-8")

    def test_text_entry_reuses_original_pipeline(self):
        self.assertIn("func build_boards_from_text(", self.pipeline)
        self.assertIn("await worker.create_reference(description, style)", self.pipeline)
        self.assertIn("return await build_boards(reference, story, seconds, style, folder, maximum_keyposes)", self.pipeline)

    def test_reference_must_be_real_and_persisted(self):
        for marker in ('generated.get("image") is Image', 'generated_reference.png', 'FileAccess.get_sha256(reference_path)', 'generated_reference_too_small'):
            self.assertIn(marker, self.pipeline)

    def test_review_and_animation_remain_gated(self):
        self.assertIn("await review_and_correct(reference, plan, style, folder)", self.pipeline)
        self.assertIn('"human_approved": false', self.pipeline)
        self.assertIn("func _review_confirmation_changed(", self.storyboard)
        self.assertIn("func _friendly_export(", self.storyboard)

    def test_android_wizard_rejects_missing_or_tiny_generated_images(self):
        self.assertIn('if not result.get("image") is Image:', self.storyboard)
        self.assertIn('generated_image.get_width() < 256', self.storyboard)
        self.assertIn('generated_image.get_height() < 256', self.storyboard)
        self.assertIn('if generated_image.save_png(path) != OK:', self.storyboard)

    def test_progress_reports_actual_stages(self):
        for stage in ("reference_generation", "analysis", "generation", "fidelity_review", "intermediate_generation", "intermediate_fidelity_review"):
            self.assertIn('"' + stage + '":', self.storyboard)

if __name__ == "__main__":
    unittest.main()
