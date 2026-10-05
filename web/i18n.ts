// Shared UI translations. English (locales/en.json) is bundled as the fallback;
// the active ox_lib locale is fetched from Lua at boot (see index.tsx) and merged on top.
import en from '../locales/en.json';

let dict: Record<string, string> = { ...(en as Record<string, string>) };

export function setLocales(data: unknown) {
  if (data && typeof data === 'object') {
    dict = { ...(en as Record<string, string>), ...(data as Record<string, string>) };
  }
}

// Mirrors ox_lib's locale(): %s / %d placeholders are filled in order.
export function locale(key: string, ...args: unknown[]): string {
  const str = dict[key] ?? key;
  if (!args.length) return str;
  let i = 0;
  return str.replace(/%[sd]/g, () => String(args[i++] ?? ''));
}
