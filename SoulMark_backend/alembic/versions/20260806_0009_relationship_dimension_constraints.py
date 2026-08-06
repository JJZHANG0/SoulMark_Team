"""Constrain relationship strength dimensions to percentage bounds."""

from collections.abc import Sequence

from alembic import op

revision: str = "20260806_0009"
down_revision: str | None = "20260806_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    constraints = {
        "ck_contacts_trust_score": "trust_score >= 0 AND trust_score <= 100",
        "ck_contacts_emotional_depth_score": (
            "emotional_depth_score >= 0 AND emotional_depth_score <= 100"
        ),
        "ck_contacts_reciprocity_score": (
            "reciprocity_score >= 0 AND reciprocity_score <= 100"
        ),
        "ck_contacts_support_score": "support_score >= 0 AND support_score <= 100",
    }
    for name, condition in constraints.items():
        op.create_check_constraint(name, "contacts", condition)


def downgrade() -> None:
    for name in (
        "ck_contacts_support_score",
        "ck_contacts_reciprocity_score",
        "ck_contacts_emotional_depth_score",
        "ck_contacts_trust_score",
    ):
        op.drop_constraint(name, "contacts", type_="check")
