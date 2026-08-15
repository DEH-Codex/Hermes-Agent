from types import SimpleNamespace

import pytest
import yaml

from gateway.config import PlatformConfig
from gateway.platforms.telegram import TelegramAdapter


CHAT_ID = -1001234567890


def _service_update(*, created=False, edited=False, update_id=1):
    message = SimpleNamespace(
        message_id=42,
        date=None,
        chat=SimpleNamespace(
            id=CHAT_ID,
            type="supergroup",
            title="Hermes HQ",
            is_forum=True,
        ),
        from_user=None,
        message_thread_id=11,
        is_topic_message=True,
        forum_topic_created=SimpleNamespace(name="briefs") if created else None,
        forum_topic_edited=SimpleNamespace(name="projects") if edited else None,
        reply_to_message=None,
        text=None,
        caption=None,
        entities=[],
        caption_entities=[],
    )
    return SimpleNamespace(
        update_id=update_id,
        message=message,
        effective_message=message,
    )


def test_message_handler_registration_matches_topic_create_and_edit_updates(
    monkeypatch,
):
    class _FilterMarker:
        def __init__(self, name):
            self.name = name

        def __or__(self, other):
            return (self.name, other.name)

    from gateway.platforms import telegram as telegram_module

    monkeypatch.setattr(
        telegram_module.filters.StatusUpdate,
        "FORUM_TOPIC_CREATED",
        _FilterMarker("created"),
    )
    monkeypatch.setattr(
        telegram_module.filters.StatusUpdate,
        "FORUM_TOPIC_EDITED",
        _FilterMarker("edited"),
    )
    monkeypatch.setattr(
        telegram_module,
        "TelegramMessageHandler",
        lambda update_filter, callback: SimpleNamespace(
            filters=update_filter,
            callback=callback,
        ),
    )
    adapter = TelegramAdapter(PlatformConfig(enabled=True, token="***"))
    registered = []
    app = SimpleNamespace(add_handler=registered.append)

    adapter._register_forum_topic_service_handler(app)

    service_handlers = [
        handler
        for handler in registered
        if handler.callback == adapter._handle_forum_topic_service_message
    ]
    assert len(service_handlers) == 1
    assert service_handlers[0].filters == ("created", "edited")


@pytest.mark.asyncio
async def test_topic_service_handler_persists_discovered_topic():
    from hermes_constants import get_hermes_home

    config_path = get_hermes_home() / "config.yaml"
    config_path.write_text(
        yaml.safe_dump({"platforms": {"telegram": {"extra": {}}}}),
        encoding="utf-8",
    )
    adapter = TelegramAdapter(
        PlatformConfig(enabled=True, token="***", extra={"require_mention": True})
    )

    await adapter._handle_forum_topic_service_message(
        _service_update(created=True), None
    )

    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    assert config["platforms"]["telegram"]["extra"]["group_topics"] == [
        {
            "chat_id": CHAT_ID,
            "topics": [{"thread_id": 11, "name": "briefs"}],
        }
    ]
