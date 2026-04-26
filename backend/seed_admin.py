"""
Run once to create the first admin user:
    python seed_admin.py
"""
import sys
from app.core.db import SessionLocal
from app.core.security import hash_password
from app.models.user import User, UserRole


def main():
    email = input("Admin email: ").strip()
    full_name = input("Full name: ").strip()
    password = input("Password: ").strip()

    db = SessionLocal()
    try:
        if db.query(User).filter(User.email == email).first():
            print(f"ERROR: {email} already exists.")
            sys.exit(1)

        admin = User(
            email=email,
            password_hash=hash_password(password),
            full_name=full_name,
            role=UserRole.admin,
            is_active=True,
        )
        db.add(admin)
        db.commit()
        db.refresh(admin)
        print(f"\n✅ Admin created — ID: {admin.id}, Email: {admin.email}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
