import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const DEFAULT_TIME_ZONE = 'Asia/Tokyo';
const HAS_OFFSET = /(Z|[+-]\d{2}:?\d{2})$/i;

export const readTimeZone = (root = '.') => {
  try {
    return JSON.parse(readFileSync(join(root, 'cms.config.json'), 'utf8')).timeZone ?? DEFAULT_TIME_ZONE;
  } catch {
    return DEFAULT_TIME_ZONE;
  }
};

export const timeZone = readTimeZone();

const offsetMs = (t, zone) => {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: zone,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
    })
      .formatToParts(t)
      .map((p) => [p.type, p.value]),
  );
  return (
    Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second) -
    Math.floor(t / 1000) * 1000
  );
};

const wallClockToInstant = (wallClockAsUtc, zone) => {
  const guess = wallClockAsUtc - offsetMs(wallClockAsUtc, zone);
  return new Date(wallClockAsUtc - offsetMs(guess, zone));
};

export const toLocalDate = (value, zone = timeZone) => {
  if (value instanceof Date) return wallClockToInstant(value.getTime(), zone);
  if (typeof value === 'string' && !HAS_OFFSET.test(value.trim())) {
    const iso = value.trim().replace(' ', 'T');
    const wallClock = new Date(`${iso}${iso.includes('T') ? '' : 'T00:00:00'}Z`);
    return Number.isNaN(wallClock.getTime()) ? value : wallClockToInstant(wallClock.getTime(), zone);
  }
  return value;
};

export const formatLocal = (date, zone = timeZone) =>
  new Intl.DateTimeFormat('sv-SE', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
