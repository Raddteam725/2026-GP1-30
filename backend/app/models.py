from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, model_validator

class ProfileUpdate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    full_name: str = Field(min_length=1, max_length=120)
    phone: str = Field(pattern=r"^\+[1-9][0-9]{7,14}$")

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
