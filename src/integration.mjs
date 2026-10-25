const routes = [
  ['/', 'index'],
  ['/lp/[slug]', 'lp/[slug]'],
  ['/news', 'news/index'],
  ['/news/[slug]', 'news/[slug]'],
  ['/events', 'events/index'],
  ['/events/[slug]', 'events/[slug]'],
];

export default function staticSiteCms() {
  return {
    name: 'static-site-cms',
    hooks: {
      'astro:config:setup': ({ injectRoute, updateConfig }) => {
        updateConfig({ vite: { ssr: { noExternal: ['static-site-cms'] } } });
        for (const [pattern, page] of routes) {
          injectRoute({ pattern, entrypoint: `static-site-cms/pages/${page}.astro` });
        }
      },
    },
  };
}
