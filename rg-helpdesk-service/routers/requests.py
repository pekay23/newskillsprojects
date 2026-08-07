from fastapi import APIRouter, Depends, Header
from sqlalchemy.orm import Session
from database import get_db
from models import HelpdeskRequest
from schemas import RequestCreate, RequestResponse
import uuid

router = APIRouter(prefix="/requests", tags=["Requests"])

@router.post("/", response_model=RequestResponse)
def create_request(
    req: RequestCreate, 
    db: Session = Depends(get_db),
    x_user_id: str = Header(default="")
):
    # Use the user ID passed by the API Gateway, or generate a dummy one for local tests
    user_id = uuid.UUID(x_user_id) if x_user_id else uuid.uuid4()
    
    db_req = HelpdeskRequest(
        title=req.title,
        description=req.description,
        requested_by=user_id
    )
    db.add(db_req)
    db.commit()
    db.refresh(db_req)
    
    # Trigger Celery background task for notification
    try:
        from worker import send_notification
        send_notification.delay(str(db_req.id), "Your request has been received and is being processed.")
    except Exception as e:
        print(f"Warning: Failed to enqueue celery task: {e}")
    
    return db_req

@router.get("/", response_model=list[RequestResponse])
def get_requests(db: Session = Depends(get_db)):
    return db.query(HelpdeskRequest).all()
