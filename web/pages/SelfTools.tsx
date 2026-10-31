import { locale } from '../i18n';
import { useEffect, useState } from 'react';
import { Shield, EyeOff, MapPin, HeartPulse, Navigation, Hash } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { fetchNui } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Button } from '../components/Button';
import type { Permissions } from '../types';

interface ToolState {
  godmode: boolean;
  invisible: boolean;
  playerBlips: boolean;
}

const mockState: ToolState = { godmode: false, invisible: false, playerBlips: false };

function ToolCard({ icon: Icon, title, description, children }: {
  icon: LucideIcon; title: string; description: string; children: React.ReactNode;
}) {
  return (
    <div
      className="rounded-sm p-4 flex items-center gap-4"
      style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}
    >
      <div
        className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
        style={{ border: '1px solid var(--rdr-border)', background: 'var(--rdr-surface-2)' }}
      >
        <Icon size={18} className="text-[var(--rdr-text)]" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[var(--rdr-heading)] font-semibold">{title}</p>
        <p className="text-[var(--rdr-muted)] text-xs italic mt-0.5">{description}</p>
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  );
}

function Switch({ on, onClick }: { on: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={on}
      className="relative w-12 h-6 rounded-full transition-colors"
      style={{
        background: on ? 'var(--rdr-green, #5a7d4f)' : 'rgba(0,0,0,0.45)',
        border: '1px solid var(--rdr-border)',
      }}
    >
      <span
        className="absolute top-0.5 w-[18px] h-[18px] rounded-full bg-white transition-all"
        style={{ left: on ? 'calc(100% - 21px)' : '2px' }}
      />
    </button>
  );
}

export function SelfTools({ permissions }: { permissions: Permissions | null }) {
  const toast = useToast();
  const [state, setState] = useState<ToolState>(mockState);

  useEffect(() => {
    fetchNui<ToolState>('getSelfToolState', {}, mockState).then((s) => s && setState({ ...mockState, ...s }));
  }, []);

  const toggle = async (key: keyof ToolState, event: string) => {
    const res = await fetchNui<{ enabled?: boolean }>(event, {}, { enabled: !state[key] });
    setState((prev) => ({ ...prev, [key]: res?.enabled === true }));
  };

  const run = async (event: string, message: string) => {
    await fetchNui(event, {}, { success: true });
    toast.push({ type: 'success', title: message });
  };

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_self_tools')}</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_self_tools_desc')}</p>
      </div>

      <div className="grid gap-3 lg:grid-cols-2">
        <ToolCard icon={Shield} title={locale('ui_godmode')} description={locale('ui_godmode_desc')}>
          <Switch on={state.godmode} onClick={() => toggle('godmode', 'toggleGodmode')} />
        </ToolCard>

        <ToolCard icon={EyeOff} title={locale('ui_invisible')} description={locale('ui_invisible_desc')}>
          <Switch on={state.invisible} onClick={() => toggle('invisible', 'toggleInvisible')} />
        </ToolCard>

        {permissions?.enablePlayerBlips && (
          <ToolCard icon={MapPin} title={locale('ui_player_blips')} description={locale('ui_player_blips_desc')}>
            <Switch on={state.playerBlips} onClick={() => toggle('playerBlips', 'togglePlayerBlips')} />
          </ToolCard>
        )}

        <ToolCard icon={Hash} title={locale('ui_toggle_ids')} description={locale('ui_toggle_ids_desc')}>
          <Button onClick={() => fetchNui('toggleIds', {}, { success: true })}>{locale('ui_toggle')}</Button>
        </ToolCard>

        <ToolCard icon={HeartPulse} title={locale('ui_self_revive')} description={locale('ui_self_revive_desc')}>
          <Button onClick={() => run('selfRevive', locale('ui_self_revived'))}>{locale('ui_revive')}</Button>
        </ToolCard>

        <ToolCard icon={Navigation} title={locale('ui_tp_marker')} description={locale('ui_tp_marker_desc')}>
          <Button onClick={() => run('teleportToMarker', locale('ui_teleported'))}>{locale('ui_teleport')}</Button>
        </ToolCard>
      </div>
    </div>
  );
}
