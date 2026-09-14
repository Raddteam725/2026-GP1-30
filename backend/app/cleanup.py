"""Run with python -m app.cleanup using the same application credentials."""
from .firebase import database, bucket

def run():
    for doc in database().collection("photo_cleanup").stream():
        blob = bucket().blob(doc.to_dict()["path"])
        if blob.exists():
            blob.delete()
        doc.reference.delete()

if __name__ == "__main__":
    run()
