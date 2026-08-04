from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ContactCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    relationship_label: str = Field(min_length=1, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)
    strength: int = Field(default=50, ge=0, le=100)
    avatar_url: str | None = Field(default=None, max_length=2048)


class ContactUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    relationship_label: str | None = Field(default=None, min_length=1, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)
    strength: int | None = Field(default=None, ge=0, le=100)
    avatar_url: str | None = Field(default=None, max_length=2048)


class ContactResponse(BaseModel):
    id: UUID
    owner_id: UUID
    name: str
    relationship_label: str
    notes: str | None
    strength: int
    avatar_url: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
