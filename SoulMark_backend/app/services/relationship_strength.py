from dataclasses import dataclass

from app.models.contact import Contact
from app.schemas.activity import RelationshipSignal

DIMENSION_FIELDS = (
    "trust_score",
    "emotional_depth_score",
    "reciprocity_score",
    "support_score",
)
DIMENSION_WEIGHTS = (0.32, 0.28, 0.20, 0.20)
MAX_AI_DIMENSION_CHANGE = 5


@dataclass(frozen=True)
class RelationshipImpact:
    trust_delta: int
    emotional_depth_delta: int
    reciprocity_delta: int
    support_delta: int
    strength_delta: int
    explanation: str | None


def calculate_strength(contact: Contact) -> int:
    weighted = (
        contact.trust_score * DIMENSION_WEIGHTS[0]
        + contact.emotional_depth_score * DIMENSION_WEIGHTS[1]
        + contact.reciprocity_score * DIMENSION_WEIGHTS[2]
        + contact.support_score * DIMENSION_WEIGHTS[3]
    )
    return max(0, min(100, round(weighted)))


def apply_relationship_impact(
    contact: Contact,
    *,
    signal: RelationshipSignal | None,
) -> RelationshipImpact:
    if signal is not None:
        confidence = signal.confidence
        raw_deltas = (
            signal.trust_delta,
            signal.emotional_depth_delta,
            signal.reciprocity_delta,
            signal.support_delta,
        )
        requested_deltas = tuple(
            round(value * confidence * MAX_AI_DIMENSION_CHANGE)
            for value in raw_deltas
        )
        explanation = signal.explanation.strip()
    else:
        requested_deltas = (0, 0, 0, 0)
        explanation = None

    previous_strength = contact.strength
    applied_deltas: list[int] = []
    for field, requested_delta in zip(
        DIMENSION_FIELDS,
        requested_deltas,
        strict=True,
    ):
        old_value = getattr(contact, field)
        new_value = max(0, min(100, old_value + requested_delta))
        setattr(contact, field, new_value)
        applied_deltas.append(new_value - old_value)

    contact.strength = calculate_strength(contact)
    return RelationshipImpact(
        trust_delta=applied_deltas[0],
        emotional_depth_delta=applied_deltas[1],
        reciprocity_delta=applied_deltas[2],
        support_delta=applied_deltas[3],
        strength_delta=contact.strength - previous_strength,
        explanation=explanation,
    )


def reverse_relationship_impact(contact: Contact, impact: RelationshipImpact) -> None:
    for field, delta in zip(
        DIMENSION_FIELDS,
        (
            impact.trust_delta,
            impact.emotional_depth_delta,
            impact.reciprocity_delta,
            impact.support_delta,
        ),
        strict=True,
    ):
        setattr(contact, field, max(0, min(100, getattr(contact, field) - delta)))
    contact.strength = calculate_strength(contact)


def reset_dimensions_to_strength(contact: Contact) -> None:
    for field in DIMENSION_FIELDS:
        setattr(contact, field, contact.strength)
