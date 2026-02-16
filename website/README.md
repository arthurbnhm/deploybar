# DeployBar Website

Marketing website for DeployBar, built with Next.js App Router.

## Stack

- Next.js 16
- React 19
- TypeScript
- Tailwind CSS v4

## Local development

```bash
cd website
npm install
npm run dev
```

## Production build

```bash
cd website
npm run build
npm run start
```

## Notes

- This folder should not commit generated assets from `.next/` or dependencies from `node_modules/`.
- Keep the landing page mostly server-rendered where possible; isolate interactivity to small client components.
