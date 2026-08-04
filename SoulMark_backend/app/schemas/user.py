from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr


class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    display_name: str
    preferred_language: str
    gender: str | None
    appearance: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
