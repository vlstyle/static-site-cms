import { z } from 'astro/zod';

export const isPreview = process.env.PREVIEW === '1';

export const showUnpublished = isPreview || process.env.SHOW_UNPUBLISHED === '1';

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;
const HAS_OFFSET = /(Z|[+-]\d{2}:?\d{2})$/i;

export const jstDate = z.preprocess((value) => {
  if (value instanceof Date) return new Date(value.getTime() - JST_OFFSET_MS);
  if (typeof value === 'string' && !HAS_OFFSET.test(value.trim())) {
    return new Date(`${value.trim().replace(' ', 'T')}${value.includes('T') || value.includes(' ') ? '' : 'T00:00:00'}+09:00`);
  }
  return value;
}, z.coerce.date());

export const isPublished = (entry: { data: { publishDate?: Date } }, now = new Date()) =>
  showUnpublished || !entry.data.publishDate || entry.data.publishDate <= now;

export const formatDate = (d: Date) =>
  d.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'Asia/Tokyo' });
