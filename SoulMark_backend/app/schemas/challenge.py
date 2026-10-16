from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.growth import GrowthSnapshot


class ChallengeStepResponse(BaseModel):
    index: int
    title: str
    instruction: str
    prompt: str
    kind: str
    min_chars: int
    response: str | None = None
    rating: int | None = None


class ChallengeSummary(BaseModel):
    key: str
    title: str
    subtitle: str
    model: str
    model_title: str
    dimension: str
    dimension_title: str
    icon: str
    duration_minutes: int
    span_days: int
    step_count: int
    reward_experience: int
    status: str  # not_started | active | completed
    completed_steps: int
    completion_count: int
    started_at: datetime | None = None
    completed_at: datetime | None = None


class ChallengeDetail(ChallengeSummary):
    intro: str
    completion_rule: str
    steps: list[ChallengeStepResponse]
    context_notes: list[str] = []


class ChallengeList(BaseModel):
    challenges: list[ChallengeSummary]
    active_count: int
    completed_count: int


class ChallengeStepSubmission(BaseModel):
    response: str = Field(default="", max_length=4000)
    rating: int | None = Field(default=None, ge=1, le=5)
    continue_anyway: bool = False


class ChallengeActionResponse(BaseModel):
    challenge: ChallengeDetail
    awarded_experience: int = 0
    growth: GrowthSnapshot | None = None
