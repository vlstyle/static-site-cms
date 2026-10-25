export default function staticSiteCms() {
  return {
    name: 'static-site-cms',
    hooks: {
      'astro:config:setup': ({ updateConfig }) => {
        updateConfig({ vite: { ssr: { noExternal: ['static-site-cms'] } } });
      },
    },
  };
}
