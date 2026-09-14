from typing import Literal
from pydantic import BaseModel, ConfigDict, Field

class ProfileUpdate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    full_name: str = Field(min_length=1, max_length=120)
    phone: str = Field(pattern=r"^\+[1-9][0-9]{7,14}$")

class ProfileCreate(ProfileUpdate):
    age_confirmed: Literal[True]
    privacy_accepted: Literal[True]

class IndividualInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    full_name: str = Field(min_length=1, max_length=120)
    age: int = Field(ge=0, le=130, strict=True)
    gender: Literal["female", "male"]
    relationship: Literal["daughter", "son", "parent", "sibling", "other"]
    photo_base64: str | None = Field(default=None, max_length=11_200_000)
