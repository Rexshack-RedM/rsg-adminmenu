import { useCallback, useEffect, useRef, useState } from 'react';
import { isDebug, useNuiEvent, fetchNui } from './hooks/useNui';
import { ToastProvider } from './components/Toast';
import { Sidebar, type AdminPage } from './components/Sidebar';
import { Dashboard } from './pages/Dashboard';
import { Statistics } from './pages/Statistics';
import { Players } from './pages/Players';
import { Whitelist } from './pages/Whitelist';
import { Finances } from './pages/Finances';
import { Reports } from './pages/Reports';
import { Admins } from './pages/Admins';
import { Logs } from './pages/Logs';
import { AdminChat } from './pages/AdminChat';
import { Teleports } from './pages/world/Teleports';
import { Coords } from './pages/world/Coords';
import { Blips } from './pages/world/Blips';
import { Spawner } from './pages/world/Spawner';
import { ServerSettings } from './pages/ServerSettings';
import { ResourceLookup } from './pages/ResourceLookup';
import { MasterActions } from './pages/MasterActions';
import { CreateReport } from './pages/player/CreateReport';
import { MyReports } from './pages/player/MyReports';
import type { OpenPayload, Permissions, SelfInfo } from './types';
import homeBg from './assets/home2.png';

// Always mounted (even while the panel itself is closed) since a jump-scared
// player is very likely not the admin with the menu open — it listens for its
// own NUI event independent of `visible` in AppInner. Drop the actual files in
// web/public/ as jumpscare.png and jumpscare.mp3; until they exist the <img>
// just fails to load (onError hides it) and audio.play() is swallowed, so this
// is safe to ship ahead of the assets.
const JUMPSCARE_SOUND_MS = 10000;

function JumpscareOverlay() {
  const [show, setShow] = useState(false);
  const [imageOk, setImageOk] = useState(true);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useNuiEvent('jumpscare', () => {
    audioRef.current?.pause();

    setShow(true);
    setImageOk(true);
    const audio = new Audio('./jumpscare.mp3');
    audio.volume = 1.0;
    audioRef.current = audio;
    audio.play().catch(() => {});
    setTimeout(() => {
      audio.pause();
      audio.currentTime = 0;
    }, JUMPSCARE_SOUND_MS);
    setTimeout(() => setShow(false), JUMPSCARE_SOUND_MS);
  });

  if (!show) return null;

  return (
    <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-black pointer-events-none">
      {imageOk && (
        <img
          src="./jumpscare.png"
          alt=""
          className="w-full h-full object-cover"
          onError={() => setImageOk(false)}
        />
      )}
    </div>
  );
}

function PanelBackground() {
  return (
    <div className="absolute inset-0 pointer-events-none" style={{ zIndex: 0 }}>
      <div
        className="absolute inset-0"
        style={{
          backgroundColor: '#000',
          backgroundImage: `url(${homeBg})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          backgroundRepeat: 'no-repeat',
        }}
      />
      <div className="absolute inset-0" style={{ background: 'rgba(0,0,0,0.5)' }} />
    </div>
  );
}

function AppInner() {
  const [visible, setVisible] = useState(isDebug);
  const [mode, setMode] = useState<'admin' | 'player'>('admin');
  const [self, setSelf] = useState<SelfInfo | null>(null);
  const [permissions, setPermissions] = useState<Permissions | null>(null);
  const [page, setPage] = useState<AdminPage>('dashboard');
  const [playerTab, setPlayerTab] = useState<'create' | 'my'>('create');

  useNuiEvent<OpenPayload>('open', (data) => {
    setMode(data.mode || 'admin');
    setSelf(data.self || null);
    setPermissions(data.permissions || null);
    // `page` is intentionally left alone here — the component stays mounted
    // across close/reopen (this handler just toggles `visible`), so the last
    // page you were on is still sitting in state. It only resets to the
    // `useState('dashboard')` initial value on an actual fresh page load,
    // i.e. a resource restart.
    setVisible(true);
  });

  useNuiEvent('close', () => setVisible(false));

  const handleClose = useCallback(() => {
    setVisible(false);
    fetchNui('close', {}, { success: true });
  }, []);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') handleClose();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleClose]);

  if (!visible) return null;

  return (
    <div
      className="fixed inset-0 flex items-center justify-center"
      style={{ padding: '3vh 3vw', fontFamily: 'var(--font-body)' }}
    >
      {mode === 'admin' ? (
        <div
          className="relative w-full h-full rounded-lg overflow-hidden shadow-2xl flex"
          style={{ border: '1px solid var(--rdr-border)' }}
        >
          <PanelBackground />
          <div className="relative flex w-full h-full" style={{ zIndex: 1 }}>
            <Sidebar self={self} permissions={permissions} currentPage={page} onPageChange={setPage} onClose={handleClose} />
            <div className="flex-1 overflow-y-auto p-8">
              <div className="w-full h-full flex flex-col">
                {page === 'dashboard' && <Dashboard self={self} onViewAllPlayers={() => setPage('players')} />}
                {page === 'statistics' && <Statistics />}
                {page === 'players' && <Players permissions={permissions} />}
                {page === 'whitelist' && <Whitelist />}
                {page === 'finances' && <Finances permissions={permissions} />}
                {page === 'reports' && <Reports permissions={permissions} />}
                {page === 'admins' && <Admins permissions={permissions} />}
                {page === 'logs' && <Logs />}
                {page === 'adminchat' && <AdminChat self={self} onNavigate={setPage} />}
                {page === 'teleports' && <Teleports permissions={permissions} />}
                {page === 'coords' && <Coords />}
                {page === 'blips' && <Blips />}
                {page === 'spawner' && <Spawner />}
                {page === 'serversettings' && <ServerSettings />}
                {page === 'resourcelookup' && <ResourceLookup />}
                {page === 'masteractions' && <MasterActions />}
              </div>
            </div>
          </div>
        </div>
      ) : (
        <div
          className="relative w-full max-w-lg rounded-lg overflow-hidden shadow-2xl"
          style={{ border: '1px solid var(--rdr-border)' }}
        >
          <PanelBackground />
          <div className="relative" style={{ zIndex: 1 }}>
            <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: '1px solid var(--rdr-line)', background: 'rgba(0,0,0,0.4)' }}>
              <h1 className="text-[var(--rdr-heading)] text-lg" style={{ fontFamily: 'var(--font-display)' }}>Report System</h1>
              <button onClick={handleClose} className="text-[var(--rdr-muted)] hover:text-[var(--rdr-heading)] px-2 py-1 rounded hover:bg-white/5">✕</button>
            </div>
            <div className="flex gap-1 px-5 pt-4">
              <button
                onClick={() => setPlayerTab('create')}
                className={`px-3 py-1.5 rounded-sm text-xs font-medium ${playerTab === 'create' ? 'bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]' : 'text-[var(--rdr-muted)] hover:bg-white/5'}`}
              >
                Create Report
              </button>
              <button
                onClick={() => setPlayerTab('my')}
                className={`px-3 py-1.5 rounded-sm text-xs font-medium ${playerTab === 'my' ? 'bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]' : 'text-[var(--rdr-muted)] hover:bg-white/5'}`}
              >
                My Reports
              </button>
            </div>
            <div className="p-5">
              {playerTab === 'create' ? <CreateReport onCreated={() => setPlayerTab('my')} /> : <MyReports />}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default function App() {
  return (
    <ToastProvider>
      <AppInner />
      <JumpscareOverlay />
    </ToastProvider>
  );
}
