from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ContactCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    relationship_label: str = Field(min_length=1, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)
    strength: int = Field(default=50, ge=0, le=100)
    position_x: float = Field(default=0.5, ge=0, le=1)
    position_y: float = Field(default=0.5, ge=0, le=1)
    symbol: str = Field(default="person.fill", min_length=1, max_length=80)
    memory: str | None = Field(default=None, max_length=4000)
    avatar_url: str | None = Field(default=None, max_length=2048)


class ContactUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    relationship_label: str | None = Field(default=None, min_length=1, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)
    strength: int | None = Field(default=None, ge=0, le=100)
    position_x: float | None = Field(default=None, ge=0, le=1)
    position_y: float | None = Field(default=None, ge=0, le=1)
    symbol: str | None = Field(default=None, min_length=1, max_length=80)
    memory: str | None = Field(default=None, max_length=4000)
    avatar_url: str | None = Field(default=None, max_length=2048)


class ContactResponse(BaseModel):
    id: UUID
    owner_id: UUID
    name: str
    relationship_label: str
    notes: str | None
    strength: int
    event_count: int
    intimacy_calculated: bool
    position_x: float
    position_y: float
    symbol: str
    memory: str | None
    avatar_url: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
