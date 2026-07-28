import hashlib
import secrets

def create_user(username, password):
    """
    Create a user record with a salted password hash.
    """

    # Generate a random salt
    salt = secrets.token_hex(16)

    # Hash the password with the salt
    password_hash = hashlib.sha256(
        (salt + password).encode("utf-8")
    ).hexdigest()

    user_record = {
        "username": username,
        "salt": salt,
        "password_hash": password_hash
    }

    return user_record


# Example usage
user = create_user("alice", "MySecurePassword123!")
print(user)
