from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, Field


class EvidenceOut(BaseModel):
    id: UUID
    slot: str
    source_type: str
    source_id: UUID | None
    quote: str
    detail: str
    occurred_on: date
    confirmed: bool


class PageCell(BaseModel):
    slot: str
    title: str
    text: str
    covered: bool
    missing: list[str]


class DraftCandidate(BaseModel):
    slot: str
    source_type: str
    source_id: UUID | None
    quote: str
    detail: str
    occurred_on: date | None
    prompt: str
    ready: bool


class Bookkeeping(BaseModel):
    contacts_count: int
    events_count: int
    reviews_count: int
    practices_count: int


class SelfAwarenessReport(BaseModel):
    generated_at: datetime
    week_start: date
    paused_at: datetime | None
    evidence_covered: int
    evidence_total: int
    weekly_step_done: bool
    weekly_step_completed_at: datetime | None
    cells: list[PageCell]
    draft: list[DraftCandidate]
    bookkeeping: Bookkeeping


class EvidenceIn(BaseModel):
    source_type: str = Field(max_length=40)
    source_id: UUID | None = None
    quote: str = Field(min_length=1, max_length=2000)
    detail: str = Field(default="", max_length=2000)
    occurred_on: date | None = None


class MarkMyLineRequest(BaseModel):
    quote: str = Field(min_length=1, max_length=2000)


class ConfirmCellRequest(BaseModel):
    slot: str = Field(max_length=20)
    text: str = Field(default="", max_length=2000)
    evidence: list[EvidenceIn] = Field(default_factory=list)
    continue_anyway: bool = False
