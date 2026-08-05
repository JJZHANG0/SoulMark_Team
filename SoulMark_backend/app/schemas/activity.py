from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PracticeCreate(BaseModel):
    contact_id: UUID | None = None
    participant_name: str = Field(min_length=1, max_length=100)
    mode_title: str = Field(min_length=1, max_length=100)
    mode_guidance: str | None = Field(default=None, max_length=2000)
    duration_seconds: int = Field(default=0, ge=0, le=24 * 60 * 60)
    user_transcript: str = Field(default="", max_length=100_000)
    assistant_transcript: str = Field(default="", max_length=100_000)


class PracticeResponse(PracticeCreate):
    id: UUID
    owner_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ReviewCreate(BaseModel):
    practice_id: UUID | None = None
    title: str = Field(min_length=1, max_length=160)
    source: Literal["scenario", "wechat", "manual"]
    transcript: str = Field(min_length=1, max_length=100_000)
    score: int = Field(ge=0, le=100)
    reason: str = Field(min_length=1, max_length=4000)
    advice: str = Field(min_length=1, max_length=4000)
    detailed_advice: str = Field(default="暂无详细建议。", min_length=1, max_length=20_000)


class ReviewResponse(ReviewCreate):
    id: UUID
    owner_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ReviewAnalysisRequest(BaseModel):
    source: Literal["scenario", "wechat", "manual"]
    transcript: str = Field(min_length=1, max_length=100_000)
    language: Literal["zh", "en"] = "zh"


class ReviewRelatedContact(BaseModel):
    id: UUID
    name: str = Field(min_length=1, max_length=100)


class ReviewAnalysisResponse(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    score: int = Field(ge=0, le=100)
    reason: str = Field(min_length=1, max_length=4000)
    brief_advice: str = Field(min_length=1, max_length=4000)
    detailed_advice: str = Field(min_length=1, max_length=20_000)
    transcript: str | None = Field(default=None, max_length=100_000)
    related_contact_name: str | None = Field(default=None, max_length=100)
    related_contact_id: UUID | None = None
    related_contact_names: list[str] = Field(default_factory=list, max_length=20)
    related_contacts: list[ReviewRelatedContact] = Field(default_factory=list, max_length=20)
    event_details: str | None = Field(default=None, max_length=20_000)


class DashboardStats(BaseModel):
    contacts_count: int
    practices_count: int
    reviews_count: int
    relationship_categories_count: int
    average_review_score: float | None
