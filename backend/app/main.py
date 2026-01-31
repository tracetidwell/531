"""
Main FastAPI application.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import Base

# Initialize FastAPI app
# Note: Database tables are created via Alembic migrations, not here
app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    docs_url=f"/api/{settings.API_VERSION}/docs",
    redoc_url=f"/api/{settings.API_VERSION}/redoc",
    openapi_url=f"/api/{settings.API_VERSION}/openapi.json"
)

# Configure CORS
# Allow localhost for development and any origin for mobile apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins (mobile apps don't use CORS, web dev needs flexibility)
    allow_credentials=False,  # Must be False when using allow_origins=["*"]
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
)


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "message": "5/3/1 Training App API",
        "version": "0.1.0",
        "docs": f"/api/{settings.API_VERSION}/docs"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


# Import routers
from app.routers import auth, users, programs, exercises, workouts, rep_maxes, warmup_templates, analytics

# Include routers
app.include_router(
    auth.router,
    prefix=f"/api/{settings.API_VERSION}/auth",
    tags=["Authentication"]
)

app.include_router(
    users.router,
    prefix=f"/api/{settings.API_VERSION}/users",
    tags=["Users"]
)

app.include_router(
    programs.router,
    prefix=f"/api/{settings.API_VERSION}/programs",
    tags=["Programs"]
)

app.include_router(
    exercises.router,
    prefix=f"/api/{settings.API_VERSION}/exercises",
    tags=["Exercises"]
)

app.include_router(
    workouts.router,
    prefix=f"/api/{settings.API_VERSION}/workouts",
    tags=["Workouts"]
)

app.include_router(
    rep_maxes.router,
    prefix=f"/api/{settings.API_VERSION}/rep-maxes",
    tags=["Rep Maxes"]
)

app.include_router(
    warmup_templates.router,
    prefix=f"/api/{settings.API_VERSION}/warmup-templates",
    tags=["Warmup Templates"]
)

app.include_router(
    analytics.router,
    prefix=f"/api/{settings.API_VERSION}/analytics",
    tags=["Analytics"]
)
