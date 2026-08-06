from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.activity import RelationshipSignal


class ContactEventCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    details: str = Field(min_length=1, max_length=20_000)
    occurred_at: datetime
    relationship_signal: RelationshipSignal | None = None
    skip_relationship_update: bool = False


class ContactEventResponse(BaseModel):
    id: UUID
    owner_id: UUID
    contact_id: UUID
    title: str
    details: str
    occurred_at: datetime
    image_url: str | None
    strength_delta: int
    impact_explanation: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
