"""
Warmup template API endpoints.
"""
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.schemas.warmup import WarmupTemplateResponse, WarmupTemplateCreateRequest
from app.services.warmup import WarmupService
from app.models.user import User
from app.models.program import LiftType
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get(
    "",
    response_model=List[WarmupTemplateResponse],
    status_code=status.HTTP_200_OK,
    summary="List warmup templates",
    description="Get all warmup templates for the current user, optionally filtered by lift type."
)
async def list_warmup_templates(
    lift_type: Optional[LiftType] = Query(None, description="Filter by lift type"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[WarmupTemplateResponse]:
    """
    Get all warmup templates for the current user.

    Returns user's custom warmup protocols for different lifts.
    Default templates for each lift are returned first.

    Optional filters:
    - lift_type: Filter by specific lift (squat, deadlift, bench_press, press)
    """
    return WarmupService.get_warmup_templates(db, current_user, lift_type)


@router.get(
    "/{template_id}",
    response_model=WarmupTemplateResponse,
    status_code=status.HTTP_200_OK,
    summary="Get warmup template",
    description="Get a specific warmup template by ID."
)
async def get_warmup_template(
    template_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WarmupTemplateResponse:
    """
    Get a specific warmup template.

    Returns the warmup template if it belongs to the current user.
    """
    return WarmupService.get_warmup_template_by_id(db, current_user, template_id)


@router.post(
    "",
    response_model=WarmupTemplateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create warmup template",
    description="Create a new custom warmup template."
)
async def create_warmup_template(
    template_data: WarmupTemplateCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WarmupTemplateResponse:
    """
    Create a custom warmup template.

    Allows users to define their own warmup protocols for specific lifts.
    If is_default is set to true, any existing default template for that lift
    will be automatically unset.

    Example warmup set types:
    - bar: Empty bar, value should be null
    - fixed: Fixed weight (e.g., 135 lbs), value is the weight
    - percentage: Percentage of training max, value is the percentage (0-100)
    """
    return WarmupService.create_warmup_template(db, current_user, template_data)


@router.put(
    "/{template_id}",
    response_model=WarmupTemplateResponse,
    status_code=status.HTTP_200_OK,
    summary="Update warmup template",
    description="Update an existing warmup template."
)
async def update_warmup_template(
    template_id: str,
    template_data: WarmupTemplateCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> WarmupTemplateResponse:
    """
    Update an existing warmup template.

    All fields are required (full replacement).
    If is_default is set to true, any existing default template for that lift
    will be automatically unset.
    """
    return WarmupService.update_warmup_template(db, current_user, template_id, template_data)


@router.delete(
    "/{template_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete warmup template",
    description="Delete a warmup template."
)
async def delete_warmup_template(
    template_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> None:
    """
    Delete a warmup template.

    Only the owner of the template can delete it.
    """
    WarmupService.delete_warmup_template(db, current_user, template_id)
