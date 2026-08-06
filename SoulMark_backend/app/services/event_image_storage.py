from functools import lru_cache
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import get_settings
from app.core.errors import AppError


class EventImageStorage:
    allowed_content_types = {"image/jpeg", "image/png", "image/heic", "image/heif"}

    def __init__(self, directory: Path, max_bytes: int) -> None:
        self.directory = directory.resolve()
        self.max_bytes = max_bytes
        self.directory.mkdir(parents=True, exist_ok=True)

    def save(self, content: bytes, content_type: str | None) -> str:
        if content_type not in self.allowed_content_types:
            raise AppError("invalid_event_image_type", "Choose a JPEG, PNG, or HEIC image.", 400)
        if len(content) > self.max_bytes:
            raise AppError("event_image_too_large", "The image must be 7 MB or smaller.", 413)
        try:
            with Image.open(BytesIO(content)) as source:
                source.verify()
            with Image.open(BytesIO(content)) as source:
                image = ImageOps.exif_transpose(source)
                image.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
                normalized = image.convert("RGB")
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise AppError("invalid_event_image", "The image could not be read.", 400) from exc

        filename = f"{uuid4()}.jpg"
        target = self.directory / filename
        temporary = self.directory / f".{filename}.tmp"
        normalized.save(temporary, format="JPEG", quality=86, optimize=True)
        temporary.replace(target)
        return f"/media/events/{filename}"

    def delete(self, image_url: str | None) -> None:
        if not image_url:
            return
        filename = Path(image_url).name
        candidate = (self.directory / filename).resolve()
        if filename and candidate.parent == self.directory:
            candidate.unlink(missing_ok=True)


@lru_cache
def get_event_image_storage() -> EventImageStorage:
    settings = get_settings()
    return EventImageStorage(settings.event_image_upload_dir, settings.event_image_max_bytes)
