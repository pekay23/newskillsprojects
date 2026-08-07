from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime

class RequestCreate(BaseModel):
    title: str
    description: Optional[str] = None

class RequestResponse(RequestCreate):
    id: UUID
    status: str
    requested_by: UUID
    created_at: datetime
    
    class Config:
        from_attributes = True

class BookingCreate(BaseModel):
    amenity_id: UUID
    start_time: datetime
    end_time: datetime

class BookingResponse(BookingCreate):
    id: UUID
    booked_by: UUID
    status: str

    class Config:
        from_attributes = True
