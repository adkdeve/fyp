from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.api.cameras import _serialize_camera
from app.core.db import Base
from app.api.deps import can_access_camera, scope_site_query
from app.models.camera import Camera
from app.models.site import Site
from app.models.user import User, UserRole


def _build_session() -> Session:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return Session(engine)


def test_supervisor_only_sees_assigned_site_cameras() -> None:
    session = _build_session()
    site_a = Site(name="Site A")
    site_b = Site(name="Site B")
    session.add_all([site_a, site_b])
    session.flush()
    session.add_all(
        [
            Camera(name="A Cam", rtsp_url="rtsp://a", site_id=site_a.id),
            Camera(name="B Cam", rtsp_url="rtsp://b", site_id=site_b.id),
        ]
    )
    supervisor = User(
        email="supervisor@example.com",
        password_hash="hash",
        full_name="Supervisor",
        role=UserRole.supervisor,
        site_id=site_a.id,
    )
    session.add(supervisor)
    session.commit()

    cameras = scope_site_query(
        session.query(Camera),
        supervisor,
        Camera.site_id,
    ).all()

    assert [camera.name for camera in cameras] == ["A Cam"]


def test_camera_access_allows_admin_and_blocks_other_sites() -> None:
    session = _build_session()
    site_a = Site(name="Site A")
    site_b = Site(name="Site B")
    session.add_all([site_a, site_b])
    session.flush()
    camera = Camera(name="B Cam", rtsp_url="rtsp://b", site_id=site_b.id)
    session.add(camera)
    admin = User(
        email="admin@example.com",
        password_hash="hash",
        full_name="Admin",
        role=UserRole.admin,
    )
    supervisor = User(
        email="supervisor@example.com",
        password_hash="hash",
        full_name="Supervisor",
        role=UserRole.supervisor,
        site_id=site_a.id,
    )
    session.add_all([admin, supervisor])
    session.commit()

    assert can_access_camera(admin, camera) is True
    assert can_access_camera(supervisor, camera) is False


def test_supervisor_camera_payload_hides_rtsp_url() -> None:
    session = _build_session()
    site = Site(name="Site A")
    session.add(site)
    session.flush()
    camera = Camera(name="A Cam", rtsp_url="rtsp://secret", site_id=site.id)
    admin = User(
        email="admin@example.com",
        password_hash="hash",
        full_name="Admin",
        role=UserRole.admin,
    )
    supervisor = User(
        email="supervisor@example.com",
        password_hash="hash",
        full_name="Supervisor",
        role=UserRole.supervisor,
        site_id=site.id,
    )

    admin_payload = _serialize_camera(camera, admin)
    supervisor_payload = _serialize_camera(camera, supervisor)

    assert admin_payload["rtsp_url"] == "rtsp://secret"
    assert supervisor_payload["rtsp_url"] is None
