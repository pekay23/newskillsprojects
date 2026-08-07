from fastapi import APIRouter, Depends, Header
from sqlalchemy.orm import Session
from database import get_db
from models import AmenityBooking
from schemas import BookingCreate, BookingResponse
import uuid

router = APIRouter(prefix="/bookings", tags=["Bookings"])

@router.post("/", response_model=BookingResponse)
def create_booking(
    booking: BookingCreate, 
    db: Session = Depends(get_db),
    x_user_id: str = Header(default="")
):
    user_id = uuid.UUID(x_user_id) if x_user_id else uuid.uuid4()
    
    db_booking = AmenityBooking(
        amenity_id=booking.amenity_id,
        start_time=booking.start_time,
        end_time=booking.end_time,
        booked_by=user_id
    )
    db.add(db_booking)
    db.commit()
    db.refresh(db_booking)
    return db_booking

@router.get("/", response_model=list[BookingResponse])
def get_bookings(db: Session = Depends(get_db)):
    return db.query(AmenityBooking).all()
