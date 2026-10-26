"""Thin wrappers around core security encryption for convenience."""
from app.core.security import decrypt_data, encrypt_data


def encrypt_token(token: str) -> str:
    """Encrypt an OAuth token for storage."""
    return encrypt_data(token)


def decrypt_token(encrypted: str) -> str:
    """Decrypt a stored OAuth token."""
    return decrypt_data(encrypted)
