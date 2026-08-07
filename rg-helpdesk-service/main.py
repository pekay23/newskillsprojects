from fastapi import FastAPI
from database import engine, Base
from routers import requests, bookings

# Auto-create tables in the database
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Raymond Gray Helpdesk Service")

# Register routers
app.include_router(requests.router)
app.include_router(bookings.router)

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "helpdesk"}
