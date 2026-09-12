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
npm ci
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

## Shared files and checks

Clone the whole repository: `lib/data.ts` imports `../design/brand-tokens.json`
relative to the `website/` directory. The committed lockfile is required for
reproducible installs.

Run `npm audit --audit-level=moderate`, `npm run typecheck`, and `npm run build`
before publishing. Source licensing and confidential security reporting are
covered by the repository's [LICENSE](../LICENSE) and [SECURITY.md](../SECURITY.md).
