"""
Script de seed — crea los usuarios iniciales del equipo QA.
Ejecutar una sola vez después de la migración inicial:

    docker exec -it qa_portal_backend python seed.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from app.database import SessionLocal
from app.models.user import User, UserRole
from app.services.auth_service import hash_password

INITIAL_USERS = [
    {
        "name": "Alexis Gonzalez",
        "email": "alexis.gonzalez@enerser.com.mx",
        "password": "1234",
        "role": UserRole.admin,
    },
    {
        "name": "Mayra Gordillo",
        "email": "mgordillo@enerser.com.mx",
        "password": "QaUserPass",
        "role": UserRole.admin,
    },
]


def seed():
    db = SessionLocal()
    try:
        created = 0
        for user_data in INITIAL_USERS:
            existing = db.query(User).filter(User.email == user_data["email"]).first()
            if existing:
                print(f"  [SKIP] {user_data['email']} ya existe")
                continue
            user = User(
                name=user_data["name"],
                email=user_data["email"],
                password_hash=hash_password(user_data["password"]),
                role=user_data["role"],
            )
            db.add(user)
            created += 1
            print(f"  [OK]   {user_data['email']} ({user_data['role'].value})")

        db.commit()
        print(f"\n{created} usuario(s) creado(s). Actualiza las contraseñas desde el portal.")
    finally:
        db.close()


if __name__ == "__main__":
    print("Creando usuarios iniciales...")
    seed()
