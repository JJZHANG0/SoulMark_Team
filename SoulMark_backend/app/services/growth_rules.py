from datetime import date, timedelta
from math import isqrt


def level_progress(balance: int) -> tuple[int, int, int]:
    balance = max(0, balance)
    # Total needed to reach level L is 25 * (L - 1) * (L + 2).
    level = max(1, (isqrt(9 + balance // 25 * 4) - 1) // 2)
    while 25 * level * (level + 3) <= balance:
        level += 1
    return level, balance - 25 * (level - 1) * (level + 2), 50 * (level + 1)


def decay_due(last_active: date, settled_through: date, today: date, balance: int) -> int:
    start = max(last_active + timedelta(days=7), settled_through)
    return min(max(0, balance), max(0, (today - start).days) * 10)


def count_completed_turns(messages: list[tuple[str, str]]) -> int:
    pending_user = False
    count = 0
    for role, text in messages:
        if not text.strip():
            continue
        if role == "user":
            pending_user = True
        elif role == "assistant" and pending_user:
            count += 1
            pending_user = False
    return count
