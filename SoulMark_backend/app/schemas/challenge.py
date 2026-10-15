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


class ChallengeList(BaseModel):
    challenges: list[ChallengeSummary]
    active_count: int
    completed_count: int


class ChallengeStepSubmission(BaseModel):
    response: str = Field(default="", max_length=4000)
    rating: int | None = Field(default=None, ge=1, le=5)


class ChallengeActionResponse(BaseModel):
    challenge: ChallengeDetail
    awarded_experience: int = 0
    growth: GrowthSnapshot | None = None


class ReportDimension(BaseModel):
    key: str
    title: str
    score: int
    completed_challenges: int
    insight: str


class ReportHighlight(BaseModel):
    challenge_title: str
    step_title: str
    response: str
    created_at: datetime


class RelationshipMix(BaseModel):
    label: str
    count: int


class SelfAwarenessReport(BaseModel):
    generated_at: datetime
    display_name: str
    headline: str
    summary: str
    overall_score: int
    level: int
    title_key: str
    experience_balance: int
    challenges_completed: int
    challenges_active: int
    reflections_count: int
    reviews_count: int
    average_review_score: float | None
    practices_count: int
    contacts_count: int
    dimensions: list[ReportDimension]
    strengths: list[str]
    growth_edges: list[str]
    next_steps: list[str]
    highlights: list[ReportHighlight]
    relationship_mix: list[RelationshipMix]
