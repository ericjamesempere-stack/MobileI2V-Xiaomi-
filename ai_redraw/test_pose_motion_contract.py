"""CPU-only regression checks for distinct story poses and stable identity seed.

These checks do not claim that diffusion weights have been run.
"""
from PIL import ImageChops
from ai_redraw.pose_guides import joints_for_action, render_pose


def test_run_cycle_changes_actual_body_joints():
    first = joints_for_action("running", 0.0)
    quarter = joints_for_action("running", 0.25)
    assert first[10] != quarter[10]
    assert first[13] != quarter[13]
    assert first[0] == quarter[0]


def test_fall_and_rise_are_reverse_motion():
    for phase in (0.0, 0.25, 0.5, 0.75, 1.0):
        assert joints_for_action("releve", phase) == joints_for_action("chute", 1.0 - phase)


def test_generated_pose_guides_have_distinct_pixels():
    a = render_pose("running", 0.0)
    b = render_pose("running", 0.25)
    assert a.size == b.size == (512, 512)
    assert ImageChops.difference(a, b).getbbox() is not None


def test_static_guide_is_repeatable():
    a = render_pose("salut", 0.25)
    b = render_pose("salut", 0.25)
    assert ImageChops.difference(a, b).getbbox() is None
