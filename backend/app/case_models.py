"""Shared case contract used by Guardian and future Volunteer integrations."""
from pydantic import BaseModel, ConfigDict, Field, model_validator

STAGES = ("report_received", "search_in_progress", "match_confirmed", "awaiting_guardian_verification", "reunited")
# Guardian-initiated terminal outcomes, reachable from any non-terminal stage
# (never sequential, never via validate_transition). "reunited" is both the
# last ordered stage and a terminal outcome; these three are terminal only.
GUARDIAN_TERMINAL_OUTCOMES = ("resolved", "cancelled")
TERMINAL_STATUSES = ("reunited", "resolved", "cancelled", "transferred_to_authority")

def age_group(age):
    """Coarse bucket retained for Admin statistics without the exact age."""
    if age <= 5: return "0-5"
    if age <= 12: return "6-12"
    if age <= 17: return "13-17"
    if age <= 30: return "18-30"
    if age <= 50: return "31-50"
    return "51+"

class CaseCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    individual_id: str = Field(min_length=1, max_length=128, pattern=r"^[^/]+$")

class GuidedReport(BaseModel):
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
            if self.latitude is None or self.longitude is None:
                raise ValueError("coordinates_required")
        elif self.latitude is not None or self.longitude is not None:
            raise ValueError("text_location_required")
        if self.completed and (self.same_location is None or self.carrying_distinctive is None or not self.clothing or (self.same_location is False and not self.last_seen_description)):
            raise ValueError("incomplete_report")
        if self.completed and self.carrying_distinctive and not self.distinctive_description:
            raise ValueError("distinctive_description_required")
        if not self.carrying_distinctive and self.distinctive_description:
            raise ValueError("unexpected_distinctive_description")
        return self
