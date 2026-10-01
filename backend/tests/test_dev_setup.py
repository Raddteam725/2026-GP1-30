import importlib.util
from pathlib import Path
import pytest

spec = importlib.util.spec_from_file_location("run_dev", Path(__file__).resolve().parents[1] / "run_dev.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

def test_external_credential_is_selected_without_reading_its_contents(tmp_path, monkeypatch):
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
    folder = tmp_path / "FirebaseKeys"
    folder.mkdir()
    credential = folder / "local.json"
    credential.write_text("not-read-by-discovery")
    runner.configure_credentials(str(folder))
    assert runner.os.environ["GOOGLE_APPLICATION_CREDENTIALS"] == str(credential.resolve())

def test_multiple_keys_require_explicit_selection(tmp_path, monkeypatch):
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
    for name in ["first.json", "second.json"]:
        (tmp_path / name).write_text("{}")
    with pytest.raises(RuntimeError):
        runner.configure_credentials(str(tmp_path))

def test_repository_credentials_are_rejected(monkeypatch):
    existing_repo_file = Path(__file__).resolve()
    monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", str(existing_repo_file))
    with pytest.raises(RuntimeError):
        runner.configure_credentials()


def test_impersonated_adc_must_belong_to_same_project():
    from types import SimpleNamespace
    runner.validate_credential_project(SimpleNamespace(service_account_email='backend@radd-32eb6.iam.gserviceaccount.com'), 'radd-32eb6')
    with pytest.raises(RuntimeError):
        runner.validate_credential_project(SimpleNamespace(service_account_email='backend@another-project.iam.gserviceaccount.com'), 'radd-32eb6')
    with pytest.raises(RuntimeError):
        runner.validate_credential_project(SimpleNamespace(), 'radd-32eb6')
