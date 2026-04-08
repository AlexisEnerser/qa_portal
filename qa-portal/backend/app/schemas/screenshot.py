from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from uuid import UUID


class ScreenshotResponse(BaseModel):
    id: UUID
    execution_result_id: UUID
    file_name: str
    file_path: Optional[str] = None
    wasabi_file_id: Optional[str] = None
    order: int
    taken_at: datetime
    taken_by: UUID | None

    model_config = {"from_attributes": True}


class ScreenshotReorder(BaseModel):
    screenshot_ids: List[UUID]  # orden deseado: primer elemento = order 0
