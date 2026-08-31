import { useEffect, useState } from 'react';
import {
  Monitor, DoorClosed, LogOut, Megaphone, RefreshCw,
  Clock, CloudSun, Gauge, Wind,
} from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Modal, ConfirmModal } from '../components/Modal';
import { Dropdown, type DropdownOption } from '../components/Dropdown';
import { Button } from '../components/Button';
import { Checkbox } from '../components/Checkbox';
import type { WorldSettings } from '../types';

const defaultSettings: WorldSettings = {
  time: { day: 'Sunday', hour: 6, minute: 0, second: 0, transition: 5, freeze: false },
  weather: { type: 'SUNNY', transition: 5, freeze: false, snow: false },
  timescale: 1,
  wind: { direction: 0, speed: 0, freeze: false },
};

const days: DropdownOption[] = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
].map((d) => ({ value: d, label: d }));

// verified against RDR2's real weather type list (RDR3 has its own weather
// system, distinct from GTA5's) — see
// https://github.com/femga/rdr3_discoveries/blob/master/weather/weather_types.lua
const weatherTypes: DropdownOption[] = [
  'SUNNY', 'CLOUDS', 'OVERCAST', 'OVERCASTDARK', 'FOG', 'MISTY', 'HIGHPRESSURE',
  'DRIZZLE', 'SHOWER', 'RAIN', 'THUNDER', 'THUNDERSTORM', 'HAIL',
  'SNOWLIGHT', 'SNOW', 'BLIZZARD', 'GROUNDBLIZZARD', 'WHITEOUT', 'SLEET', 'SANDSTORM', 'HURRICANE',
].map((w) => ({ value: w, label: w.charAt(0) + w.slice(1).toLowerCase() }));

function Panel({ icon, title, description, children }: { icon: React.ReactNode; title: string; description: string; children: React.ReactNode }) {
  return (
    <div className="rounded-lg p-4 space-y-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
      <div className="flex items-center gap-3">
        <div className="w-9 h-9 rounded-sm flex items-center justify-center shrink-0 bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">
          {icon}
        </div>
        <div>
          <p className="text-[var(--rdr-heading)] text-sm font-semibold">{title}</p>
          <p className="text-[var(--rdr-muted)] text-xs">{description}</p>
        </div>
      </div>
      {children}
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="text-xs text-[var(--rdr-muted)]">{label}</label>
      <div className="mt-1">{children}</div>
    </div>
  );
}

const inputCls = 'w-full bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]';

export function ServerSettings() {
  const toast = useToast();
  const [serverState, refreshState] = useNuiData<{ closed: boolean }>('getServerState', {}, { closed: false });
  const [remoteSettings] = useNuiData<WorldSettings>('getWorldSettings', {}, defaultSettings);

  const [time, setTime] = useState(defaultSettings.time);
  const [weather, setWeather] = useState(defaultSettings.weather);
  const [timescale, setTimescale] = useState(defaultSettings.timescale);
  const [wind, setWind] = useState(defaultSettings.wind);

  useEffect(() => {
    if (!remoteSettings) return;
    setTime(remoteSettings.time);
    setWeather(remoteSettings.weather);
    setTimescale(remoteSettings.timescale);
    setWind(remoteSettings.wind);
  }, [remoteSettings]);

  const [showAnnounce, setShowAnnounce] = useState(false);
  const [confirmKickAll, setConfirmKickAll] = useState(false);
  const [confirmClose, setConfirmClose] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  const run = async (key: string, event: string, data: Record<string, unknown>, successMsg: string) => {
    setBusy(key);
    const res = await fetchNui<{ success: boolean }>(event, data, { success: true });
    setBusy(null);
    if (res.success) toast.push({ type: 'success', title: successMsg });
    else toast.push({ type: 'error', title: 'Action failed' });
    return res.success;
  };

  const closed = serverState?.closed ?? false;

  return (
    <div className="space-y-4 pb-6">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><Monitor size={22} /> Server Settings</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">Manage server operations, world state, and player actions</p>
      </div>

      <Panel icon={<Monitor size={16} />} title="Server Actions" description="Manage server operations and player actions">
        <div className="grid grid-cols-2 gap-2">
          <Button
            variant="outline"
            tone={closed ? 'green' : 'red'}
            isLoading={busy === 'close'}
            onClick={() => setConfirmClose(true)}
          >
            <DoorClosed size={14} /> {closed ? 'Reopen Server' : 'Close Server for Players'}
          </Button>
          <Button variant="outline" tone="red" isLoading={busy === 'kickall'} onClick={() => setConfirmKickAll(true)}>
            <LogOut size={14} /> Kick All Players
          </Button>
          <Button variant="outline" tone="accent" onClick={() => setShowAnnounce(true)}>
            <Megaphone size={14} /> Announcement
          </Button>
          <Button
            variant="outline"
            isLoading={busy === 'refresh'}
            onClick={() => run('refresh', 'refreshResources', {}, 'Resources refreshed')}
          >
            <RefreshCw size={14} /> Refresh Resources
          </Button>
        </div>
        <p className="text-[var(--rdr-faint)] text-[11px]">
          Restarting the FXServer process itself isn't available from here. It needs an external process manager (txAdmin, pm2, etc.) to relaunch it safely.
        </p>
      </Panel>

      <div className="grid grid-cols-2 gap-4">
        <Panel icon={<Clock size={16} />} title="Time Control" description="Manage server time and progression">
          <Field label="Set Day"><Dropdown value={time.day ?? 'Sunday'} onChange={(v) => setTime((t) => ({ ...t, day: v }))} options={days} /></Field>
          <div className="grid grid-cols-3 gap-2">
            <Field label="Hour (0-23)"><input type="number" min={0} max={23} className={inputCls} value={time.hour} onChange={(e) => setTime((t) => ({ ...t, hour: Number(e.target.value) }))} /></Field>
            <Field label="Minute (0-59)"><input type="number" min={0} max={59} className={inputCls} value={time.minute} onChange={(e) => setTime((t) => ({ ...t, minute: Number(e.target.value) }))} /></Field>
            <Field label="Second (0-59)"><input type="number" min={0} max={59} className={inputCls} value={time.second} onChange={(e) => setTime((t) => ({ ...t, second: Number(e.target.value) }))} /></Field>
          </div>
          <Field label="Transition Time (seconds)"><input type="number" min={0} className={inputCls} value={time.transition} onChange={(e) => setTime((t) => ({ ...t, transition: Number(e.target.value) }))} /></Field>
          <Checkbox checked={time.freeze} onChange={(v) => setTime((t) => ({ ...t, freeze: v }))} label="Freeze Time" />
          <Button
            variant="solid"
            tone="accent"
            fullWidth
            isLoading={busy === 'time'}
            onClick={() => run('time', 'setTimeSettings', time, 'Time settings applied')}
          >
            Apply Time Settings
          </Button>
        </Panel>

        <Panel icon={<CloudSun size={16} />} title="Weather Control" description="Manage server weather conditions">
          <Field label="Set Weather Type"><Dropdown value={weather.type} onChange={(v) => setWeather((w) => ({ ...w, type: v }))} options={weatherTypes} /></Field>
          <Field label="Transition Time (seconds)"><input type="number" min={0} className={inputCls} value={weather.transition} onChange={(e) => setWeather((w) => ({ ...w, transition: Number(e.target.value) }))} /></Field>
          <div className="flex items-center gap-4">
            <Checkbox checked={weather.freeze} onChange={(v) => setWeather((w) => ({ ...w, freeze: v }))} label="Freeze Weather" />
            <Checkbox checked={weather.snow} onChange={(v) => setWeather((w) => ({ ...w, snow: v }))} label="Permanent Snow Mode" />
          </div>
          <Button
            variant="solid"
            tone="green"
            fullWidth
            isLoading={busy === 'weather'}
            onClick={() => run('weather', 'setWeatherSettings', weather, 'Weather settings applied')}
          >
            Apply Weather Settings
          </Button>
        </Panel>

        <Panel icon={<Gauge size={16} />} title="Timescale Control" description="Adjust time progression speed">
          <Field label="Set Timescale (0-100)">
            <input type="number" min={0} max={100} className={inputCls} value={timescale} onChange={(e) => setTimescale(Number(e.target.value))} />
          </Field>
          <p className="text-[var(--rdr-faint)] text-[11px]">Higher values = faster time progression</p>
          <Button
            variant="solid"
            tone="amber"
            fullWidth
            isLoading={busy === 'timescale'}
            onClick={() => run('timescale', 'setTimescale', { timescale }, 'Timescale applied')}
          >
            Apply Timescale
          </Button>
        </Panel>

        <Panel icon={<Wind size={16} />} title="Wind Control" description="Manage wind direction and speed">
          <div className="grid grid-cols-2 gap-2">
            <Field label="Direction (0-360°)"><input type="number" min={0} max={360} className={inputCls} value={wind.direction} onChange={(e) => setWind((w) => ({ ...w, direction: Number(e.target.value) }))} /></Field>
            <Field label="Speed (0-100)"><input type="number" min={0} max={100} className={inputCls} value={wind.speed} onChange={(e) => setWind((w) => ({ ...w, speed: Number(e.target.value) }))} /></Field>
          </div>
          <Checkbox checked={wind.freeze} onChange={(v) => setWind((w) => ({ ...w, freeze: v }))} label="Freeze Wind" />
          <Button
            variant="solid"
            tone="red"
            fullWidth
            isLoading={busy === 'wind'}
            onClick={() => run('wind', 'setWindSettings', wind, 'Wind settings applied')}
          >
            Apply Wind Settings
          </Button>
        </Panel>
      </div>

      {showAnnounce && <AnnouncementModal onClose={() => setShowAnnounce(false)} onSent={() => { setShowAnnounce(false); toast.push({ type: 'success', title: 'Announcement sent' }); }} />}

      {confirmKickAll && (
        <ConfirmModal
          title="Kick All Players"
          message="This will disconnect every player currently online except you. Continue?"
          confirmLabel="Kick Everyone"
          danger
          onCancel={() => setConfirmKickAll(false)}
          onConfirm={async () => { setConfirmKickAll(false); await run('kickall', 'kickAllPlayers', {}, 'All players kicked'); }}
        />
      )}

      {confirmClose && (
        <ConfirmModal
          title={closed ? 'Reopen Server' : 'Close Server for Players'}
          message={closed ? 'New players will be able to join again.' : 'New connections will be rejected until you reopen the server. Admins can still join.'}
          confirmLabel={closed ? 'Reopen' : 'Close Server'}
          danger={!closed}
          onCancel={() => setConfirmClose(false)}
          onConfirm={async () => {
            setConfirmClose(false);
            const ok = await run('close', 'toggleCloseServer', {}, closed ? 'Server reopened' : 'Server closed to new players');
            if (ok) refreshState();
          }}
        />
      )}
    </div>
  );
}

function AnnouncementModal({ onClose, onSent }: { onClose: () => void; onSent: () => void }) {
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);

  const submit = async () => {
    if (!message.trim()) return;
    setSending(true);
    const res = await fetchNui<{ success: boolean }>('sendAnnouncement', { message: message.trim() }, { success: true });
    setSending(false);
    if (res.success) onSent();
  };

  return (
    <Modal title="Server Announcement" subtitle="Broadcast a message to every online player" onClose={onClose} width="max-w-md">
      <div className="space-y-3">
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={4}
          placeholder="Type your announcement..."
          className="w-full bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)] resize-none"
        />
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button variant="solid" tone="accent" disabled={!message.trim()} isLoading={sending} onClick={submit}><Megaphone size={13} /> Send</Button>
        </div>
      </div>
    </Modal>
  );
}
