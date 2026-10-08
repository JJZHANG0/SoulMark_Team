from datetime import date

from app.services.growth_rules import count_completed_turns, decay_due, level_progress


def test_increasing_levels():
    assert level_progress(0) == (1, 0, 100)
    assert level_progress(100) == (2, 0, 150)
    assert level_progress(249) == (2, 149, 150)
    assert level_progress(250) == (3, 0, 200)
    assert level_progress(450) == (4, 0, 250)


def test_decay_grace_and_floor():
    active = date(2026, 10, 1)
    assert decay_due(active, active, date(2026, 10, 8), 100) == 0
    assert decay_due(active, active, date(2026, 10, 9), 100) == 10
    assert decay_due(active, active, date(2026, 10, 11), 100) == 30
    assert decay_due(active, date(2026, 10, 10), date(2026, 10, 11), 100) == 10
    assert decay_due(active, active, date(2026, 10, 11), 7) == 7
    assert decay_due(active, active, date(2026, 10, 11), 0) == 0
    assert decay_due(date(2026, 9, 29), date(2026, 9, 29), date(2026, 10, 7), 100) == 10


def test_completed_turns():
    assert count_completed_turns([("assistant", "hello")]) == 0
    assert count_completed_turns([("user", "  "), ("assistant", "hi")]) == 0
    assert count_completed_turns([("user", "hi")]) == 0
    assert count_completed_turns([("user", "a"), ("user", "b"), ("assistant", "c")]) == 1
    assert (
        count_completed_turns(
            [("user", "a"), ("assistant", "b"), ("user", "c"), ("assistant", "d")]
        )
        == 2
    )
