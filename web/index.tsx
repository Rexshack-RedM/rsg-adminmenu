import React from 'react';
import ReactDOM from 'react-dom/client';
import { fetchNui, isDebug } from './hooks/useNui';
import { setLocales } from './i18n';
import './styles.css';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Load the active ox_lib locale before importing the app so module-level labels
// (sidebar items, dropdown options, ...) are built in the right language.
async function boot() {
  if (!isDebug) {
    for (let i = 0; i < 20; i++) {
      const data = await fetchNui<Record<string, string>>('getLocales');
      if (data && Object.keys(data).length > 0) {
        setLocales(data);
        break;
      }
      await sleep(500);
    }
  }
  const { default: App } = await import('./App');
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );
}

boot();
