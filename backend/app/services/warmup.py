"""
Warmup template service with business logic.
"""
from sqlalchemy.orm import Session
from typing import List, Optional
from fastapi import HTTPException, status
from app.models.warmup import WarmupTemplate
from app.models.user import User
from app.models.program import LiftType
from app.schemas.warmup import WarmupTemplateResponse, WarmupTemplateCreateRequest


class WarmupService:
    """Service for handling warmup template operations."""

    @staticmethod
    def get_warmup_templates(
        db: Session,
        user: User,
        lift_type: Optional[LiftType] = None
    ) -> List[WarmupTemplateResponse]:
        """
        Get user's warmup templates.

        Args:
            db: Database session
            user: Current user
            lift_type: Optional filter by lift type

        Returns:
            List of WarmupTemplateResponse
        """
        query = db.query(WarmupTemplate).filter(WarmupTemplate.user_id == user.id)

        if lift_type:
            query = query.filter(WarmupTemplate.lift_type == lift_type)

        templates = query.order_by(
            WarmupTemplate.lift_type,
            WarmupTemplate.is_default.desc(),  # Default templates first
            WarmupTemplate.name
        ).all()

        return [WarmupTemplateResponse.model_validate(template) for template in templates]

    @staticmethod
    def create_warmup_template(
        db: Session,
        user: User,
        template_data: WarmupTemplateCreateRequest
    ) -> WarmupTemplateResponse:
        """
        Create a new warmup template.

        If is_default is True, unset any existing default template for this lift type.

        Args:
            db: Database session
            user: Current user
            template_data: Template creation data

        Returns:
            WarmupTemplateResponse
        """
        # If this is being set as default, unset any existing default for this lift
        if template_data.is_default:
            existing_default = db.query(WarmupTemplate).filter(
                WarmupTemplate.user_id == user.id,
                WarmupTemplate.lift_type == template_data.lift_type,
                WarmupTemplate.is_default == True # noqa: E712
            ).first()

            if existing_default:
                existing_default.is_default = False
                db.add(existing_default)

        # Convert Pydantic models to dicts for JSON storage
        sets_data = [set_item.model_dump() for set_item in template_data.sets]

        template = WarmupTemplate(
            user_id=user.id,
            name=template_data.name,
            lift_type=template_data.lift_type,
            is_default=template_data.is_default,
            sets=sets_data
        )

        db.add(template)
        db.commit()
        db.refresh(template)

        return WarmupTemplateResponse.model_validate(template)

    @staticmethod
    def get_warmup_template_by_id(
        db: Session,
        user: User,
        template_id: str
    ) -> WarmupTemplateResponse:
        """
        Get a specific warmup template by ID.

        Args:
            db: Database session
            user: Current user
            template_id: Template ID

        Returns:
            WarmupTemplateResponse

        Raises:
            HTTPException: If template not found or doesn't belong to user
        """
        template = db.query(WarmupTemplate).filter(
            WarmupTemplate.id == template_id,
            WarmupTemplate.user_id == user.id
        ).first()

        if not template:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Warmup template not found"
            )

        return WarmupTemplateResponse.model_validate(template)

    @staticmethod
    def delete_warmup_template(
        db: Session,
        user: User,
        template_id: str
    ) -> None:
        """
        Delete a warmup template.

        Args:
            db: Database session
            user: Current user
            template_id: Template ID

        Raises:
            HTTPException: If template not found or doesn't belong to user
        """
        template = db.query(WarmupTemplate).filter(
            WarmupTemplate.id == template_id,
            WarmupTemplate.user_id == user.id
        ).first()

        if not template:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Warmup template not found"
            )

        db.delete(template)
        db.commit()

    @staticmethod
    def update_warmup_template(
        db: Session,
        user: User,
        template_id: str,
        template_data: WarmupTemplateCreateRequest
    ) -> WarmupTemplateResponse:
        """
        Update a warmup template.

        If is_default is True, unset any existing default template for this lift type.

        Args:
            db: Database session
            user: Current user
            template_id: Template ID
            template_data: Updated template data

        Returns:
            WarmupTemplateResponse

        Raises:
            HTTPException: If template not found or doesn't belong to user
        """
        template = db.query(WarmupTemplate).filter(
            WarmupTemplate.id == template_id,
            WarmupTemplate.user_id == user.id
        ).first()

        if not template:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Warmup template not found"
            )

        # If this is being set as default, unset any existing default for this lift
        if template_data.is_default and not template.is_default:
            existing_default = db.query(WarmupTemplate).filter(
                WarmupTemplate.user_id == user.id,
                WarmupTemplate.lift_type == template_data.lift_type,
                WarmupTemplate.is_default == True, # noqa: E712
                WarmupTemplate.id != template_id  # Don't include current template
            ).first()

            if existing_default:
                existing_default.is_default = False
                db.add(existing_default)

        # Convert Pydantic models to dicts for JSON storage
        sets_data = [set_item.model_dump() for set_item in template_data.sets]

        template.name = template_data.name
        template.lift_type = template_data.lift_type
        template.is_default = template_data.is_default
        template.sets = sets_data

        db.add(template)
        db.commit()
        db.refresh(template)

        return WarmupTemplateResponse.model_validate(template)
