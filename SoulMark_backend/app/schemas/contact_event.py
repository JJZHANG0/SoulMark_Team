from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ContactEventCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    details: str = Field(min_length=1, max_length=20_000)
    occurred_at: datetime


class ContactEventResponse(ContactEventCreate):
    id: UUID
    owner_id: UUID
    contact_id: UUID
    image_url: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
