import { z } from 'astro/zod';
import { timeZone, toLocalDate } from './timezone.ts';

export const isPreview = process.env.PREVIEW === '1';

export const showUnpublished = isPreview || process.env.SHOW_UNPUBLISHED === '1';

export const localDate = z.preprocess((value) => toLocalDate(value), z.coerce.date());

export const isPublished = (entry: { data: { publishDate?: Date } }, now = new Date()) =>
  showUnpublished || !entry.data.publishDate || entry.data.publishDate <= now;

export const formatDate = (d: Date) =>
  d.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long', day: 'numeric', timeZone });
