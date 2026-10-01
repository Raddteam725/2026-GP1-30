import re
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

# The current release supports Saudi Arabian phone numbers (Sprint-0 scope);
# other numbering plans are future work. Any common way of writing a Saudi
# number is accepted -- +966…, 00966…, 966… or the national 0… form, with
# spaces/dashes and Arabic-Indic digits -- and stored in one canonical
# international form. Shared by Guardian self-registration and Admin
# Volunteer creation; the Flutter validator mirrors it (lib/shared/saudi_phone.dart).
SAUDI_PHONE_CANONICAL = r"^\+966[1-9][0-9]{8}$"
_ARABIC_INDIC = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")

def normalize_saudi_phone(value):
    """Canonical +966XXXXXXXXX, or None when the value is not a Saudi number."""
    if not isinstance(value, str):
        return None
    digits = re.sub(r"[\s\-().]", "", value.translate(_ARABIC_INDIC))
    if digits.startswith("+"):
        digits = digits[1:]
    if digits.startswith("00966"):
        national = digits[5:]
    elif digits.startswith("966"):
        national = digits[3:]
    elif digits.startswith("0"):
        national = digits[1:]
    else:
        return None
    return "+966" + national if re.fullmatch(r"[1-9][0-9]{8}", national) else None

class ProfileUpdate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    full_name: str = Field(min_length=1, max_length=120)
    phone: str = Field(min_length=1, max_length=32)

    @field_validator("phone")
    @classmethod
    def saudi_phone(cls, value):
        normalized = normalize_saudi_phone(value)
        if normalized is None:
            raise ValueError("saudi_phone_required")
        return normalized

class ProfileCreate(ProfileUpdate):
    age_confirmed: Literal[True]
    privacy_accepted: Literal[True]

class FcmRegistration(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    # The registration identifier the Firebase Messaging SDK issues to the
    # installation -- opaque to this backend, never interpreted or logged.
    token: str = Field(min_length=1, max_length=4096)
    # This installation's CURRENT in-app language (Radd's own explicit
    # selection, e.g. Localizations.localeOf(context) -- not the device's
    # system locale, which may differ). Determines which language the visible
    # notification text is sent in for this registration. Optional and
    # defaults to "en" (Radd's own default) so older/unaware clients still work.
    locale: Literal["en", "ar"] = "en"

class FcmUnregister(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    token: str = Field(min_length=1, max_length=4096)

class IndividualInput(BaseModel):
    registration_period_id: str | None = Field(default=None, min_length=1, max_length=128, pattern=r"^[^/]+$")
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    full_name: str = Field(min_length=1, max_length=120)
    age: int = Field(ge=0, le=130, strict=True)
    gender: Literal["female", "male"]
    relationship: Literal["child", "parent", "other"]
    relationship_other: str | None = Field(default=None, max_length=120)
    photo_base64: str | None = Field(default=None, max_length=11_200_000)

    @model_validator(mode="after")
    def relationship_other_matches_selection(self):
        if self.relationship == "other":
            if not self.relationship_other:
                raise ValueError("relationship_other_required")
        elif self.relationship_other:
            raise ValueError("unexpected_relationship_other")
        return self
