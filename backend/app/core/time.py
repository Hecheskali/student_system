from datetime import UTC, datetime


def is_before_now(value: datetime) -> bool:
    """Compare stored datetimes to now, tolerating SQLite's naive values."""
    now = datetime.now(UTC)
    if value.tzinfo is None or value.utcoffset() is None:
        return value < now.replace(tzinfo=None)
    return value < now
