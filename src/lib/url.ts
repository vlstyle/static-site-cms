const base = import.meta.env.BASE_URL.replace(/\/+$/, '');

export const withBase = (path: string) => {
  if (!path.startsWith('/') || path.startsWith('//')) return path;
  if (base && (path === base || path.startsWith(`${base}/`))) return path;
  return `${base}${path}`;
};

export const withBaseInHtml = (html: string) =>
  base
    ? html.replace(/(\s(?:href|src)=")(\/[^"]*)"/g, (_, attribute: string, path: string) => `${attribute}${withBase(path)}"`)
    : html;
