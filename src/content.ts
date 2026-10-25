import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const image = z.string().optional();

const blocks = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('hero'),
    heading: z.string(),
    subheading: z.string().optional(),
    image,
    ctaLabel: z.string().optional(),
    ctaUrl: z.string().optional(),
  }),
  z.object({
    type: z.literal('features'),
    heading: z.string().optional(),
    items: z.array(z.object({ title: z.string(), text: z.string() })),
  }),
  z.object({
    type: z.literal('text'),
    body: z.string(),
  }),
  z.object({
    type: z.literal('event-list'),
    heading: z.string().optional(),
    limit: z.number().int().positive().default(3),
  }),
  z.object({
    type: z.literal('cta'),
    heading: z.string(),
    label: z.string(),
    url: z.string(),
  }),
]);

export type Block = z.infer<typeof blocks>;

const news = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/news' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    publishDate: z.coerce.date().optional(),
    image,
  }),
});

const events = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/events' }),
  schema: z.object({
    title: z.string(),
    startDate: z.coerce.date(),
    endDate: z.coerce.date().optional(),
    venue: z.string().optional(),
    applyUrl: z.string().optional(),
    publishDate: z.coerce.date().optional(),
    image,
  }),
});

const lp = defineCollection({
  loader: glob({ pattern: '**/*.yaml', base: './src/content/lp' }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    publishDate: z.coerce.date().optional(),
    blocks: z.array(blocks),
  }),
});

export const collections = { news, events, lp };
