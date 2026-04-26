from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.site import Site
from ..models.user import User
from ..schemas.camera import SiteCreate, SiteOut
from .deps import require_admin, get_current_user

router = APIRouter(prefix="/sites", tags=["Sites"])


@router.get("", response_model=list[SiteOut])
def list_sites(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return db.query(Site).order_by(Site.name).all()


@router.post("", response_model=SiteOut, status_code=201)
def create_site(
    body: SiteCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    site = Site(**body.model_dump())
    db.add(site)
    db.commit()
    db.refresh(site)
    return site


@router.delete("/{site_id}", status_code=204)
def delete_site(
    site_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    site = db.get(Site, site_id)
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    db.delete(site)
    db.commit()
