import os
from celery import Celery

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# Initialize Celery app
celery_app = Celery("helpdesk_worker", broker=REDIS_URL, backend=REDIS_URL)

@celery_app.task
def send_notification(request_id: str, message: str):
    """
    Simulates sending a push notification or email to the user.
    """
    print(f"[CELERY] Sending notification for Request {request_id}: {message}")
    return True

@celery_app.task
def send_satisfaction_survey(request_id: str):
    """
    Simulates sending a survey 24 hours after ticket closure.
    """
    print(f"[CELERY] Sending satisfaction survey for closed Request {request_id}")
    return True
