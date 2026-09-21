"""Shared push delivery for both roles: the ONE place FCM is actually called.

Order of every case-state-changing operation (see cases.py, volunteer.py,
volunteer_workflow.py): authorize -> validate -> commit the authoritative
state AND the durable notification record in one transaction -> then, still
inside the same request, deliver() attempts the push immediately. FCM is a
signal only; the receiving app refetches from the API.

Durability: each notification document carries one `deliveries/{registration}`
receipt per target installation. A receipt with `sent_at` means FCM accepted
the message; a short lease prevents two concurrent attempts (this request and
a reconciliation run) sending the same message twice. Every failure other than
Firebase's definitive UnregisteredError leaves the receipt absent, so the
message stays retryable by the reconciliation job (local_jobs.retry_alerts
locally; a managed scheduler calling the maintenance endpoint on Cloud Run).

Bounded: all registrations of one notification go out in a single
messaging.send_each round-trip, and every Firebase Admin HTTP call is capped
by the app-level httpTimeout (see firebase.firebase_app) -- a stalled FCM
network path can delay the API response by at most that bound, never hang it,
and never affects the already-committed state. Never raises.
"""
import logging
import time
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore, messaging

LEASE = timedelta(seconds=60)
log = logging.getLogger("radd.timing")

def deliver(db, notification_ref, registrations, build_message, *, app=None):
    """Push one durable notification to the given registrations.

    `build_message(registration_dict) -> messaging.Message`. Returns a small
    summary (counts and FCM round-trip milliseconds) for instrumentation.
    """
    summary = {"attempted": 0, "sent": 0, "failed": 0, "removed": 0, "fcm_ms": 0}
    try:
        targets = []
        for registration in registrations:
            data = registration.to_dict() or {}
            receipt = notification_ref.collection("deliveries").document(registration.id)
            @firestore.transactional
            def claim(tx, receipt=receipt):
                current = receipt.get(transaction=tx).to_dict() or {}
                now = datetime.now(timezone.utc)
                if current.get("sent_at") or current.get("lease_until", now) > now:
                    return False
                tx.set(receipt, {"lease_until": now + LEASE})
                return True
            if not claim(db.transaction()):
                continue
            targets.append((registration, receipt, build_message(data)))
        if not targets:
            return summary
        summary["attempted"] = len(targets)
        started = time.monotonic()
        try:
            batch = messaging.send_each([message for _, _, message in targets], app=app)
        except Exception as error:
            # The whole call failed (network, service): release every lease
            # so the reconciliation job (or the next event) retries them all.
            logging.getLogger(__name__).warning("Push batch failed (%s)", type(error).__name__)
            for _, receipt, _ in targets:
                receipt.delete()
            summary["failed"] = len(targets)
            return summary
        finally:
            summary["fcm_ms"] = int((time.monotonic() - started) * 1000)
        for (registration, receipt, _), response in zip(targets, batch.responses):
            if response.success:
                receipt.set({"sent_at": firestore.SERVER_TIMESTAMP})
                summary["sent"] += 1
            elif isinstance(response.exception, messaging.UnregisteredError):
                # Firebase's own definitive "this registration no longer
                # exists" -- the only outcome that removes a registration.
                receipt.delete()
                registration.reference.delete()
                summary["removed"] += 1
            else:
                receipt.delete()  # Transient: retryable, registration untouched.
                summary["failed"] += 1
        return summary
    except Exception as error:
        logging.getLogger(__name__).warning("Push delivery failed (%s)", type(error).__name__)
        return summary
    finally:
        # T4/T5 for the integration timeline: when the immediate attempt
        # began and how FCM answered. Identifiers only -- no names, tokens,
        # text or locations.
        if summary["attempted"]:
            log.info("Radd timing: T5 push notification=%s attempted=%d sent=%d failed=%d removed=%d fcm_ms=%d",
                     notification_ref.id, summary["attempted"], summary["sent"], summary["failed"], summary["removed"], summary["fcm_ms"])
