export const isPreview = process.env.PREVIEW === '1';

export const isPublished = (entry: { data: { publishDate?: Date } }, now = new Date()) =>
  isPreview || !entry.data.publishDate || entry.data.publishDate <= now;

export const formatDate = (d: Date) =>
  d.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'Asia/Tokyo' });
