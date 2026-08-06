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


class RelationshipSignal(BaseModel):
    contact_name: str = Field(min_length=1, max_length=100)
    trust_delta: float = Field(ge=-1, le=1)
    emotional_depth_delta: float = Field(ge=-1, le=1)
    reciprocity_delta: float = Field(ge=-1, le=1)
    support_delta: float = Field(ge=-1, le=1)
    confidence: float = Field(default=0.7, ge=0, le=1)
    explanation: str = Field(min_length=1, max_length=1000)


class RelationshipProfile(BaseModel):
    trust_score: int = Field(ge=0, le=100)
    emotional_depth_score: int = Field(ge=0, le=100)
    reciprocity_score: int = Field(ge=0, le=100)
    support_score: int = Field(ge=0, le=100)
    explanation: str = Field(min_length=1, max_length=2000)


class ReviewRelationshipImpactCreate(BaseModel):
    contact_id: UUID
    relationship_signal: RelationshipSignal


class ReviewCreate(BaseModel):
    practice_id: UUID | None = None
    title: str = Field(min_length=1, max_length=160)
    source: Literal["scenario", "wechat", "manual"]
    transcript: str = Field(min_length=1, max_length=100_000)
    score: int = Field(ge=0, le=100)
    reason: str = Field(min_length=1, max_length=4000)
    advice: str = Field(min_length=1, max_length=4000)
    detailed_advice: str = Field(default="暂无详细建议。", min_length=1, max_length=20_000)
    relationship_impacts: list[ReviewRelationshipImpactCreate] = Field(
        default_factory=list,
        max_length=20,
        exclude=True,
    )


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
    relationship_signal: RelationshipSignal | None = None


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
    relationship_signals: list[RelationshipSignal] = Field(default_factory=list, max_length=20)
    event_details: str | None = Field(default=None, max_length=20_000)


class DashboardStats(BaseModel):
    contacts_count: int
    practices_count: int
    reviews_count: int
    relationship_categories_count: int
    average_review_score: float | None
