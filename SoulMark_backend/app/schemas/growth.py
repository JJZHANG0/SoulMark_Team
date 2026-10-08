from datetime import date

from pydantic import BaseModel


class GrowthSnapshot(BaseModel):
    balance: int
    level: int
    level_experience: int
    next_level_experience: int
    peak_level: int
    chat_experience_today: int
    title_key: str
    next_title_level: int | None
    decayed_experience: int = 0
    next_decay_date: date
