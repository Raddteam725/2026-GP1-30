"""Versioned development consent. No acceptance is inferred or migrated."""
from pydantic import BaseModel, ConfigDict, field_validator
from datetime import datetime
from typing import Literal
from fastapi import HTTPException
from firebase_admin import firestore

TERMS_VERSION = 'draft-2026-09'
PRIVACY_VERSION = 'draft-2026-09'


def current(data):
    return (data.get('terms_version') == TERMS_VERSION and
            data.get('privacy_version') == PRIVACY_VERSION and
            isinstance(data.get('terms_accepted_at'), datetime) and
            isinstance(data.get('privacy_accepted_at'), datetime))


def state(data):
    return {'consent_current': current(data), 'required_terms_version': TERMS_VERSION,
            'required_privacy_version': PRIVACY_VERSION}


class ConsentInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    accepted: Literal[True]
    terms_version: str
    privacy_version: str

    @field_validator('accepted', mode='before')
    @classmethod
    def explicit_boolean(cls, value):
        if value is not True:
            raise ValueError('Explicit acceptance is required')
        return value


def accept(service, value):
    @firestore.transactional
    def save(tx):
        service.profile(tx, require_assignment=False, require_consent=False)
        if value.terms_version != TERMS_VERSION or value.privacy_version != PRIVACY_VERSION:
            raise HTTPException(409, detail='consent_version_changed')
        data = service.user.get(transaction=tx).to_dict() or {}
        if not current(data):
            tx.update(service.user, {
                'terms_version': TERMS_VERSION, 'privacy_version': PRIVACY_VERSION,
                'terms_accepted_at': firestore.SERVER_TIMESTAMP,
                'privacy_accepted_at': firestore.SERVER_TIMESTAMP})
    save(service.db.transaction())
    return state(service.user.get().to_dict() or {})
