import { locale } from '../i18n';
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
].map((d) => ({ value: d, label: locale('ui_day_' + d.toLowerCase()) }));

// verified against RDR2's real weather type list (RDR3 has its own weather
// system, distinct from GTA5's) — see
// https://github.com/femga/rdr3_discoveries/blob/master/weather/weather_types.lua
const weatherTypes: DropdownOption[] = [
  'SUNNY', 'CLOUDS', 'OVERCAST', 'OVERCASTDARK', 'FOG', 'MISTY', 'HIGHPRESSURE',
  'DRIZZLE', 'SHOWER', 'RAIN', 'THUNDER', 'THUNDERSTORM', 'HAIL',
  'SNOWLIGHT', 'SNOW', 'BLIZZARD', 'GROUNDBLIZZARD', 'WHITEOUT', 'SLEET', 'SANDSTORM', 'HURRICANE',
].map((w) => ({ value: w, label: locale('ui_weather_' + w.toLowerCase()) }));

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
    else toast.push({ type: 'error', title: locale('ui_action_failed') });
    return res.success;
  };

  const closed = serverState?.closed ?? false;

  return (
    <div className="space-y-4 pb-6">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><Monitor size={22} /> {locale('ui_server_settings')}</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_manage_server_operations_world_state_and_pla')}</p>
      </div>

      <Panel icon={<Monitor size={16} />} title={locale('ui_server_actions')} description={locale('ui_manage_server_operations_and_player_actions')}>
        <div className="grid grid-cols-2 gap-2">
          <Button
            variant="outline"
            tone={closed ? 'green' : 'red'}
            isLoading={busy === 'close'}
            onClick={() => setConfirmClose(true)}
          >
            <DoorClosed size={14} /> {closed ? locale('ui_reopen_server') : locale('ui_close_server_for_players')}
          </Button>
          <Button variant="outline" tone="red" isLoading={busy === 'kickall'} onClick={() => setConfirmKickAll(true)}>
            <LogOut size={14} /> {locale('ui_kick_all_players')}
          </Button>
          <Button variant="outline" tone="accent" onClick={() => setShowAnnounce(true)}>
            <Megaphone size={14} /> {locale('ui_announcement')}
          </Button>
          <Button
            variant="outline"
            isLoading={busy === 'refresh'}
            onClick={() => run('refresh', 'refreshResources', {}, locale('ui_resources_refreshed'))}
          >
            <RefreshCw size={14} /> {locale('ui_refresh_resources')}
          </Button>
        </div>
        <p className="text-[var(--rdr-faint)] text-[11px]">
          {locale('ui_restarting_the_fxserver_process_itself_isn_t')}
        </p>
      </Panel>

      <div className="grid grid-cols-2 gap-4">
        <Panel icon={<Clock size={16} />} title={locale('ui_time_control')} description={locale('ui_manage_server_time_and_progression')}>
          <Field label={locale('ui_set_day')}><Dropdown value={time.day ?? 'Sunday'} onChange={(v) => setTime((t) => ({ ...t, day: v }))} options={days} /></Field>
          <div className="grid grid-cols-3 gap-2">
            <Field label={locale('ui_hour_0_23')}><input type="number" min={0} max={23} className={inputCls} value={time.hour} onChange={(e) => setTime((t) => ({ ...t, hour: Number(e.target.value) }))} /></Field>
            <Field label={locale('ui_minute_0_59')}><input type="number" min={0} max={59} className={inputCls} value={time.minute} onChange={(e) => setTime((t) => ({ ...t, minute: Number(e.target.value) }))} /></Field>
            <Field label={locale('ui_second_0_59')}><input type="number" min={0} max={59} className={inputCls} value={time.second} onChange={(e) => setTime((t) => ({ ...t, second: Number(e.target.value) }))} /></Field>
          </div>
          <Field label={locale('ui_transition_time_seconds')}><input type="number" min={0} className={inputCls} value={time.transition} onChange={(e) => setTime((t) => ({ ...t, transition: Number(e.target.value) }))} /></Field>
          <Checkbox checked={time.freeze} onChange={(v) => setTime((t) => ({ ...t, freeze: v }))} label={locale('ui_freeze_time')} />
          <Button
            variant="solid"
            tone="accent"
            fullWidth
            isLoading={busy === 'time'}
            onClick={() => run('time', 'setTimeSettings', time, locale('ui_time_settings_applied'))}
          >
            {locale('ui_apply_time_settings')}
          </Button>
        </Panel>

        <Panel icon={<CloudSun size={16} />} title={locale('ui_weather_control')} description={locale('ui_manage_server_weather_conditions')}>
          <Field label={locale('ui_set_weather_type')}><Dropdown value={weather.type} onChange={(v) => setWeather((w) => ({ ...w, type: v }))} options={weatherTypes} /></Field>
          <Field label={locale('ui_transition_time_seconds')}><input type="number" min={0} className={inputCls} value={weather.transition} onChange={(e) => setWeather((w) => ({ ...w, transition: Number(e.target.value) }))} /></Field>
          <div className="flex items-center gap-4">
            <Checkbox checked={weather.freeze} onChange={(v) => setWeather((w) => ({ ...w, freeze: v }))} label={locale('ui_freeze_weather')} />
            <Checkbox checked={weather.snow} onChange={(v) => setWeather((w) => ({ ...w, snow: v }))} label={locale('ui_permanent_snow_mode')} />
          </div>
          <Button
            variant="solid"
            tone="green"
            fullWidth
            isLoading={busy === 'weather'}
            onClick={() => run('weather', 'setWeatherSettings', weather, locale('ui_weather_settings_applied'))}
          >
            {locale('ui_apply_weather_settings')}
          </Button>
        </Panel>

        <Panel icon={<Gauge size={16} />} title={locale('ui_timescale_control')} description={locale('ui_adjust_time_progression_speed')}>
          <Field label={locale('ui_set_timescale_0_100')}>
            <input type="number" min={0} max={100} className={inputCls} value={timescale} onChange={(e) => setTimescale(Number(e.target.value))} />
          </Field>
          <p className="text-[var(--rdr-faint)] text-[11px]">{locale('ui_higher_values_faster_time_progression')}</p>
          <Button
            variant="solid"
            tone="amber"
            fullWidth
            isLoading={busy === 'timescale'}
            onClick={() => run('timescale', 'setTimescale', { timescale }, locale('ui_timescale_applied'))}
          >
            {locale('ui_apply_timescale')}
          </Button>
        </Panel>

        <Panel icon={<Wind size={16} />} title={locale('ui_wind_control')} description={locale('ui_manage_wind_direction_and_speed')}>
          <div className="grid grid-cols-2 gap-2">
            <Field label={locale('ui_direction_0_360')}><input type="number" min={0} max={360} className={inputCls} value={wind.direction} onChange={(e) => setWind((w) => ({ ...w, direction: Number(e.target.value) }))} /></Field>
            <Field label={locale('ui_speed_0_100')}><input type="number" min={0} max={100} className={inputCls} value={wind.speed} onChange={(e) => setWind((w) => ({ ...w, speed: Number(e.target.value) }))} /></Field>
          </div>
          <Checkbox checked={wind.freeze} onChange={(v) => setWind((w) => ({ ...w, freeze: v }))} label={locale('ui_freeze_wind')} />
          <Button
            variant="solid"
            tone="red"
            fullWidth
            isLoading={busy === 'wind'}
            onClick={() => run('wind', 'setWindSettings', wind, locale('ui_wind_settings_applied'))}
          >
            {locale('ui_apply_wind_settings')}
          </Button>
        </Panel>
      </div>

      {showAnnounce && <AnnouncementModal onClose={() => setShowAnnounce(false)} onSent={() => { setShowAnnounce(false); toast.push({ type: 'success', title: locale('ui_announcement_sent') }); }} />}

      {confirmKickAll && (
        <ConfirmModal
          title={locale('ui_kick_all_players')}
          message={locale('ui_this_will_disconnect_every_player_currently')}
          confirmLabel={locale('ui_kick_everyone')}
          danger
          onCancel={() => setConfirmKickAll(false)}
          onConfirm={async () => { setConfirmKickAll(false); await run('kickall', 'kickAllPlayers', {}, locale('ui_all_players_kicked')); }}
        />
      )}

      {confirmClose && (
        <ConfirmModal
          title={closed ? locale('ui_reopen_server') : locale('ui_close_server_for_players')}
          message={closed ? locale('ui_new_players_will_be_able_to_join_again') : locale('ui_new_connections_will_be_rejected_until_you_r')}
          confirmLabel={closed ? locale('ui_reopen') : locale('ui_close_server')}
          danger={!closed}
          onCancel={() => setConfirmClose(false)}
          onConfirm={async () => {
            setConfirmClose(false);
            const ok = await run('close', 'toggleCloseServer', {}, closed ? locale('ui_server_reopened') : locale('ui_server_closed_to_new_players'));
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
    <Modal title={locale('ui_server_announcement')} subtitle={locale('ui_broadcast_a_message_to_every_online_player')} onClose={onClose} width="max-w-md">
      <div className="space-y-3">
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={4}
          placeholder={locale('ui_type_your_announcement')}
          className="w-full bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)] resize-none"
        />
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>{locale('ui_cancel')}</Button>
          <Button variant="solid" tone="accent" disabled={!message.trim()} isLoading={sending} onClick={submit}><Megaphone size={13} /> {locale('ui_send')}</Button>
        </div>
      </div>
    </Modal>
  );
}
