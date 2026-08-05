from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=100)
    preferred_language: Literal["zh", "en"] | None = None
    gender: Literal["male", "female", "unspecified"] | None = None
    appearance: Literal["auto", "light", "dark"] | None = None
    communication_goal: str | None = Field(default=None, max_length=80)
    onboarding_completed: bool | None = None


class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    display_name: str
    preferred_language: str
    gender: str | None
    appearance: str
    communication_goal: str | None
    onboarding_completed: bool
    onboarding_completed_at: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
