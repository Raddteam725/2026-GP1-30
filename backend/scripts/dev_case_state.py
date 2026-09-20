"""Development-only local command: advance a real case through the
Volunteer-driven stages so the Guardian side can be exercised end-to-end now.

The Guardian app only ever reacts to backend state. The stages after
"Report Received" are written by the Volunteer workflow (Start Search,
Match Confirmed, Awaiting Guardian Verification, handover -> Reunited). Until
the Volunteer app is integrated, this command writes exactly the same
canonical fields that workflow writes -- status, stage_timestamps,
updated_at, the Guardian's own notification document, and the best-effort
Guardian push -- against the same shared `cases` document, so every Guardian
screen (Home/Cases/Case Status timeline, QR eligibility, Notifications, FCM)
sees real Firestore state. It is NOT production behaviour: it refuses to
touch anything but a case in the active *development* event, runs only
locally with existing Admin credentials, and is never exposed through the API.

    python scripts/dev_case_state.py --list
    python scripts/dev_case_state.py --case-id RD-XXXX --to search_in_progress
    python scripts/dev_case_state.py --case-id RD-XXXX --to match_confirmed
    python scripts/dev_case_state.py --case-id RD-XXXX --to awaiting_guardian_verification
    python scripts/dev_case_state.py --case-id RD-XXXX --to reunited

Credentials are resolved exactly like run_dev.py (GOOGLE_APPLICATION_CREDENTIALS
or --credentials-dir); the key never enters the repository.
"""
import argparse
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

DEV_ACTOR = "development-script"
GUARDIAN_NOTIFIED = ("search_in_progress", "match_confirmed", "awaiting_guardian_verification", "reunited")

def development_event(db):
    from app.events import active_event
    event = active_event(db)
    if event.to_dict().get("environment") != "development":
        raise SystemExit("Refusing: the active event is not a development event.")
    return event

def list_cases(db):
    event = development_event(db)
    docs = db.collection("cases").where(filter=FieldFilter("event_id", "==", event.id)).stream()
    rows = sorted(((d.id, (d.to_dict() or {}).get("status"), (d.to_dict() or {}).get("individual_name")) for d in docs), key=lambda r: r[0])
    if not rows:
        print("No cases in the active development event.")
    for case_id, status, name in rows:
        print(f"{case_id}  {status:32}  {name}")

def advance(db, case_id, target):
    """Moves `case_id` to the NEXT stage only (never skips, never reverses)."""
    from app.case_models import STAGES
    from app.push import notify_guardian
    event = development_event(db)
    ref = db.collection("cases").document(case_id)
    @firestore.transactional
    def step(tx):
        data = ref.get(transaction=tx).to_dict()
        if not data or data.get("event_id") != event.id:
            raise SystemExit("Case not found in the active development event.")
        current = data["status"]
        if current not in STAGES[:-1] or STAGES.index(target) != STAGES.index(current) + 1:
            raise SystemExit(f"Only the next stage is allowed from '{current}'.")
        now = firestore.SERVER_TIMESTAMP
        update = {"status": target, "updated_at": now, f"stage_timestamps.{target}": now}
        if target == "search_in_progress":
            update["joined_by"] = [*data.get("joined_by", []), DEV_ACTOR]
        if target == "match_confirmed":
            update["confirmed_by"] = DEV_ACTOR
        if target == "reunited":
            # Mirrors VolunteerWorkflow.handover_found, with the verification
            # proof explicitly labelled as development-only.
            update.update(handed_over_at=now, handed_over_by=DEV_ACTOR, guardian_verification={
                "method": "development", "volunteer_uid": DEV_ACTOR, "guardian_id": data["guardian_id"],
                "case_id": case_id, "verified_at": now})
            person = db.collection("users").document(data["guardian_id"]).collection("individuals").document(data["individual_id"])
            if (person.get(transaction=tx).to_dict() or {}).get("active_case_id") == case_id:
                tx.update(person, {"active_case_id": None, "updated_at": now})
        tx.update(ref, update)
        if target in GUARDIAN_NOTIFIED:
            tx.set(db.collection("users").document(data["guardian_id"]).collection("notifications").document(f"{case_id}-{target}"),
                {"case_id": case_id, "event_id": event.id, "kind": "status_update", "status": target, "created_at": now, "read_at": None})
        return data["guardian_id"]
    guardian_id = step(db.transaction())
    if target in GUARDIAN_NOTIFIED:
        notify_guardian(guardian_id, kind="status_update", status=target, case_id=case_id, event_id=event.id)
    print(f"{case_id}: now '{target}'.")

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--credentials-dir")
    parser.add_argument("--list", action="store_true", help="List the active development event's cases.")
    parser.add_argument("--case-id")
    parser.add_argument("--to", choices=["search_in_progress", "match_confirmed", "awaiting_guardian_verification", "reunited"])
    args = parser.parse_args()
    if not args.list and not (args.case_id and args.to):
        parser.error("Use --list, or --case-id with --to.")
    from run_dev import configure_credentials
    try:
        configure_credentials(args.credentials_dir)
    except RuntimeError as error:
        raise SystemExit(str(error))
    from app.firebase import database
    db = database()
    if args.list:
        list_cases(db)
    else:
        advance(db, args.case_id, args.to)

if __name__ == "__main__":
    main()
