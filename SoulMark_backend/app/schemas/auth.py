import re

from pydantic import BaseModel, EmailStr, Field, field_validator

CHINA_PHONE_PATTERN = re.compile(r"^(?:\+?86)?1[3-9]\d{9}$")


def validate_phone_number(value: str) -> str:
    compact = value.strip().replace(" ", "").replace("-", "")
    if not CHINA_PHONE_PATTERN.fullmatch(compact):
        raise ValueError("请输入有效的中国大陆手机号")
    return compact


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=100)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class PhoneCodeRequest(BaseModel):
    phone_number: str

    _validate_phone = field_validator("phone_number")(validate_phone_number)


class PhoneLoginRequest(PhoneCodeRequest):
    code: str = Field(pattern=r"^\d{6}$")


class WeChatLoginRequest(BaseModel):
    code: str = Field(min_length=1, max_length=512)


class MessageResponse(BaseModel):
    message: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_seconds: int
