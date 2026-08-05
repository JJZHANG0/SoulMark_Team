from functools import lru_cache
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import get_settings
from app.core.errors import AppError


class AvatarStorage:
    allowed_content_types = {"image/jpeg", "image/png"}

    def __init__(self, directory: Path, max_bytes: int) -> None:
        self.directory = directory.resolve()
        self.max_bytes = max_bytes
        self.directory.mkdir(parents=True, exist_ok=True)

    def save(self, content: bytes, content_type: str | None) -> str:
        if content_type not in self.allowed_content_types:
            raise AppError("invalid_avatar_type", "Choose a JPEG, PNG, or HEIC image.", 400)
        if len(content) > self.max_bytes:
            raise AppError("avatar_too_large", "The avatar must be 5 MB or smaller.", 413)

        try:
            with Image.open(BytesIO(content)) as source:
                source.verify()
            with Image.open(BytesIO(content)) as source:
                image = ImageOps.exif_transpose(source)
                image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                normalized = image.convert("RGB")
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise AppError(
                "invalid_avatar_image", "The uploaded image could not be read.", 400
            ) from exc

        filename = f"{uuid4()}.jpg"
        target = self.directory / filename
        temporary = self.directory / f".{filename}.tmp"
        normalized.save(temporary, format="JPEG", quality=86, optimize=True)
        temporary.replace(target)
        return f"/media/avatars/{filename}"

    def delete(self, avatar_url: str | None) -> None:
        if not avatar_url:
            return
        filename = Path(avatar_url).name
        if not filename or filename != Path(filename).name:
            return
        candidate = (self.directory / filename).resolve()
        if candidate.parent != self.directory:
            return
        candidate.unlink(missing_ok=True)


@lru_cache
def get_avatar_storage() -> AvatarStorage:
    settings = get_settings()
    return AvatarStorage(settings.avatar_upload_dir, settings.avatar_max_bytes)
