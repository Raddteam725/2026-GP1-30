from types import SimpleNamespace
import secrets
import pytest
from scripts import create_test_volunteer as cli
from scripts.provision_volunteer import provision
from test_volunteer import db


def args(**changes):
    return SimpleNamespace(**(dict(email='test@example.test', name='Test Volunteer',
        phone='0500000000', volunteer_id='VOL-TEST-002', existing_uid=None,
        apply=False) | changes))


def missing(*a, **kw):
    raise cli.auth.UserNotFoundError('not found')


def test_preview_never_creates_auth_or_profile_or_reads_password(db, monkeypatch):
    monkeypatch.setattr(cli.auth, 'get_user_by_email', missing)
    monkeypatch.setattr(cli.auth, 'create_user', lambda **kw: pytest.fail('write'))
    before = dict(db.data)
    cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(),
                password_reader=lambda prompt: pytest.fail('password requested'))
    assert db.data == before


def test_wrong_project_rejected_before_auth_lookup(db, monkeypatch):
    monkeypatch.setattr(cli.auth, 'get_user_by_email', lambda *a, **kw: pytest.fail('lookup'))
    with pytest.raises(ValueError, match='project'):
        cli.execute(db, SimpleNamespace(project_id='other'), args())


def test_duplicate_id_refused(db, monkeypatch):
    monkeypatch.setattr(cli.auth, 'get_user_by_email', missing)
    db.data['users/one']['volunteer_id'] = 'VOL-TEST-002'
    with pytest.raises(ValueError, match='already in use'):
        cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(apply=True))


def test_existing_auth_requires_explicit_uid_and_never_changes_password(db, monkeypatch):
    user = SimpleNamespace(uid='second', email='test@example.test', disabled=False,
                           provider_data=[SimpleNamespace(provider_id='password')])
    monkeypatch.setattr(cli.auth, 'get_user_by_email', lambda *a, **kw: user)
    monkeypatch.setattr(cli.auth, 'create_user', lambda **kw: pytest.fail('duplicate Auth'))
    with pytest.raises(ValueError, match='Confirm its UID'):
        cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(apply=True))
    cli.execute(db, SimpleNamespace(project_id=cli.PROJECT),
                args(apply=True, existing_uid='second'),
                password_reader=lambda prompt: pytest.fail('password'))
    assert db.data['users/second']['role'] == 'volunteer'
    assert db.data['users/second']['active'] is True
    assert 'events/test-event/volunteers/second' not in db.data
    before = dict(db.data)
    cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(apply=True))
    assert db.data == before


def test_create_only_refuses_existing_volunteer_and_guardian(db):
    for role in ('volunteer', 'guardian'):
        db.data['users/existing'] = {'role': role}
        with pytest.raises(ValueError, match='overwrite'):
            provision(db, SimpleNamespace(uid='existing', email='e@example.test'),
                      'Name', '0500000000', 'V-new', create_only=True)
        assert db.data['users/existing'] == {'role': role}


def test_apply_creates_exact_profile_without_assignment(db, monkeypatch, capsys):
    monkeypatch.setattr(cli.auth, 'get_user_by_email', missing)
    monkeypatch.setattr(cli.sys.stdin, 'isatty', lambda: True)
    test_password = secrets.token_urlsafe(16)
    def create(**kw):
        assert kw['email'] == 'test@example.test'
        assert kw['disabled'] is False
        assert kw['password'] == test_password
        return SimpleNamespace(uid='new-test', email=kw['email'])
    monkeypatch.setattr(cli.auth, 'create_user', create)
    cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(apply=True),
                password_reader=lambda prompt: test_password)
    assert test_password not in capsys.readouterr().out
    profile = db.data['users/new-test']
    assert set(profile) == {'role', 'active', 'full_name', 'email', 'phone',
                            'volunteer_id', 'created_at', 'updated_at'}
    assert profile['volunteer_id'] == 'VOL-TEST-002'
    assert 'events/test-event/volunteers/new-test' not in db.data


def test_partial_failure_keeps_auth_and_reports_recovery_uid(db, monkeypatch, capsys):
    test_password = secrets.token_urlsafe(16)
    monkeypatch.setattr(cli.auth, 'get_user_by_email', missing)
    monkeypatch.setattr(cli.sys.stdin, 'isatty', lambda: True)
    monkeypatch.setattr(cli.auth, 'create_user', lambda **kw: SimpleNamespace(uid='partial'))
    monkeypatch.setattr(cli.auth, 'delete_user', lambda *a, **kw: pytest.fail('delete'))
    monkeypatch.setattr(cli, 'provision', lambda *a, **kw: (_ for _ in ()).throw(RuntimeError()))
    with pytest.raises(RuntimeError):
        cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(apply=True),
                    password_reader=lambda prompt: test_password)
    assert '--existing-uid partial' in capsys.readouterr().out


def test_existing_unrelated_profile_is_never_overwritten(db, monkeypatch):
    user = SimpleNamespace(uid='one', email='test@example.test', disabled=False,
                           provider_data=[SimpleNamespace(provider_id='password')])
    monkeypatch.setattr(cli.auth, 'get_user_by_email', lambda *a, **kw: user)
    before = dict(db.data['users/one'])
    with pytest.raises(ValueError, match='differs'):
        cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(apply=True))
    assert db.data['users/one'] == before


def test_password_confirmation_failure_never_creates_account(db, monkeypatch):
    monkeypatch.setattr(cli.auth, 'get_user_by_email', missing)
    monkeypatch.setattr(cli.sys.stdin, 'isatty', lambda: True)
    monkeypatch.setattr(cli.auth, 'create_user', lambda **kw: pytest.fail('write'))
    passwords = iter([secrets.token_urlsafe(16), secrets.token_urlsafe(16)])
    with pytest.raises(ValueError, match='Passwords must match'):
        cli.execute(db, SimpleNamespace(project_id=cli.PROJECT), args(apply=True),
                    password_reader=lambda prompt: next(passwords))
