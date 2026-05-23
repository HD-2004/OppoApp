from fastapi import Header, HTTPException, status

from .models import Principal, Role


async def get_current_principal(
    x_user_id: str | None = Header(default=None),
    x_role: Role | None = Header(default=None),
) -> Principal:
    """Local auth shim.

    Production should verify Cognito JWTs and derive these fields from token
    claims. The headers keep local development and tests straightforward.
    """
    if not x_user_id or not x_role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing local auth headers.",
        )
    return Principal(user_id=x_user_id, role=x_role)


def require_role(principal: Principal, *roles: Role) -> None:
    if principal.role not in roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient role for this action.",
        )
