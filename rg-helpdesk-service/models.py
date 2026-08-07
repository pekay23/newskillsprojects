from sqlalchemy import Column, String, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
import uuid
from datetime import datetime
from database import Base

class HelpdeskRequest(Base):
    __tablename__ = "requests"
    __table_args__ = {"schema": "helpdesk"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    status = Column(String, default="open")  # open, closed, escalated
    requested_by = Column(UUID(as_uuid=True), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
class AmenityBooking(Base):
    __tablename__ = "bookings"
    __table_args__ = {"schema": "helpdesk"}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    amenity_id = Column(UUID(as_uuid=True), nullable=False)
    booked_by = Column(UUID(as_uuid=True), nullable=False)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=False)
    status = Column(String, default="confirmed")
