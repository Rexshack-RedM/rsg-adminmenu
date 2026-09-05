import { useCallback, useEffect, useRef, useState } from 'react';

const isDebug = typeof (window as any).GetParentResourceName !== 'function';

if (isDebug) {
  document.body.style.background = '#0a0908';
}

export { isDebug };

export function debugNuiEvent(action: string, data: unknown) {
  window.dispatchEvent(new MessageEvent('message', { data: { action, data } }));
}

export function useNuiEvent<T = unknown>(action: string, handler: (data: T) => void) {
  const savedHandler = useRef(handler);
  useEffect(() => { savedHandler.current = handler; }, [handler]);
  useEffect(() => {
    function eventListener(event: MessageEvent) {
      let payload = event.data;
      if (typeof payload === 'string') { try { payload = JSON.parse(payload); } catch { /* ignore */ } }
      const { action: eventAction, data } = payload ?? {};
      if (eventAction === action) savedHandler.current((data ?? {}) as T);
    }
    window.addEventListener('message', eventListener);
    return () => window.removeEventListener('message', eventListener);
  }, [action]);
}

export async function fetchNui<T = unknown>(
  eventName: string,
  data: Record<string, unknown> = {},
  mockData?: T
): Promise<T> {
  if (isDebug && mockData !== undefined) {
    console.log(`[NUI Dev] ${eventName}:`, mockData);
    return mockData;
  }
  if (isDebug) {
    console.warn(`[NUI Dev] No mock for '${eventName}'. Pass mockData as 3rd arg.`);
    return {} as T;
  }
  const resourceName = (window as any).GetParentResourceName();
  try {
    const response = await fetch(`https://${resourceName}/${eventName}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      console.error(`[NUI] ${eventName} failed: HTTP ${response.status}`);
      return (mockData ?? {}) as T;
    }
    return await response.json();
  } catch (err) {
    console.error(`[NUI] ${eventName} failed`, err);
    return (mockData ?? {}) as T;
  }
}

// NUI CEF does not grant clipboard-write, so in-game copies go through Lua
// (ox_lib setClipboard). Browser debug still uses the normal clipboard API.
export async function copyToClipboard(text: string): Promise<void> {
  if (!text) return;
  if (isDebug) {
    await navigator.clipboard?.writeText(text);
    return;
  }
  await fetchNui('copyToClipboard', { text }, { success: true });
}

// Module-level cache shared across every mount of every page for the lifetime of the
// NUI session. Lets a page show its last-known values the instant you switch back to
// it instead of resetting to a blank/loading state and popping the numbers back in —
// it still refreshes in the background on every mount, just without the visible flicker.
const nuiCache = new Map<string, unknown>();

function cacheKey(eventName: string, data: Record<string, unknown>) {
  const keys = Object.keys(data);
  if (keys.length === 0) return eventName;
  return `${eventName}?${JSON.stringify(data)}`;
}

export function useNuiData<T = unknown>(
  eventName: string,
  data: Record<string, unknown> = {},
  mockData?: T
): [T | undefined, () => Promise<T>] {
  const key = cacheKey(eventName, data);
  const [value, setValue] = useState<T | undefined>(() => nuiCache.get(key) as T | undefined);
  const dataRef = useRef(data);
  dataRef.current = data;
  const mockRef = useRef(mockData);
  mockRef.current = mockData;

  const refresh = useCallback(() => {
    return fetchNui<T>(eventName, dataRef.current, mockRef.current).then((result) => {
      nuiCache.set(key, result);
      setValue(result);
      return result;
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [eventName, key]);

  useEffect(() => {
    setValue(nuiCache.get(key) as T | undefined);
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return [value, refresh];
}

if (isDebug) {
  setTimeout(() => debugNuiEvent('open', {
    mode: 'admin',
    self: { name: 'Dev Admin', citizenid: 'DEV1234', job: { label: 'Sheriff' } },
    permissions: { isAdmin: true, enablePlayerBlips: true, canManageHistory: true, canManageAdmins: true, atLeastMod: true, atLeastAdmin: true, fullAccess: true },
  }), 100);
}
