"""Shared case contract used by Guardian, Volunteer and Admin integrations."""
from pydantic import BaseModel, ConfigDict, Field, model_validator

STAGES = ("report_received", "search_in_progress", "match_confirmed", "awaiting_guardian_verification", "reunited")
# Guardian-initiated terminal outcomes, reachable from any non-terminal stage
# (never sequential, never via validate_transition). "reunited" is both the
# last ordered stage and a terminal outcome; the others are terminal only.
GUARDIAN_TERMINAL_OUTCOMES = ("resolved", "cancelled")
# Admin-initiated terminal outcome: the case leaves Radd's active reunification
# workflow for handling by the appropriate authority (cases.refer_to_authority).
ADMIN_TERMINAL_OUTCOME = "referred_to_authority"
TERMINAL_STATUSES = ("reunited", "resolved", "cancelled", ADMIN_TERMINAL_OUTCOME)

def age_group(age):
    """Coarse bucket retained for Admin statistics without the exact age."""
    if age <= 5: return "0-5"
    if age <= 17: return "6-17"
    if age <= 59: return "18-59"
    return "60+"

class CaseCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    individual_id: str = Field(min_length=1, max_length=128, pattern=r"^[^/]+$")

class GuidedReport(BaseModel):
    """The Guided Assistant's predefined questions, and nothing more.

    Required before completion: the last-seen location question (Yes/No),
    clothing, the distinctive-item question (Yes/No, with a description only
    when Yes). `additional_information` and `last_seen_description` are
    optional free text -- a "No" to the location question records no
    location and never blocks completion.
    """
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    completed: bool = False
    same_location: bool | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90, allow_inf_nan=False)
    longitude: float | None = Field(default=None, ge=-180, le=180, allow_inf_nan=False)
    last_seen_description: str = Field(default="", max_length=1000)
    clothing: str = Field(default="", max_length=1000)
    carrying_distinctive: bool | None = None
    distinctive_description: str = Field(default="", max_length=1000)
    additional_information: str = Field(default="", max_length=2000)

    @model_validator(mode="after")
    def location_and_details(self):
        if self.same_location:
            if (self.latitude is None) != (self.longitude is None):
                raise ValueError("coordinates_required")
        elif self.latitude is not None or self.longitude is not None:
            raise ValueError("text_location_required")
        if self.completed and (self.same_location is None or self.carrying_distinctive is None or not self.clothing):
            raise ValueError("incomplete_report")
        if self.completed and self.carrying_distinctive and not self.distinctive_description:
            raise ValueError("distinctive_description_required")
        if not self.carrying_distinctive and self.distinctive_description:
            raise ValueError("unexpected_distinctive_description")
        return self
