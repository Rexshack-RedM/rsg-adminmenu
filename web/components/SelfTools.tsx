import { locale } from '../i18n';
import { useState, type ReactNode } from 'react';
import { Shield, EyeOff, HeartPulse, MapPin, Radar, DoorOpen } from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from './Toast';
import type { Permissions } from '../types';

type ToggleTool = 'godmode' | 'invisible' | 'playerblips' | 'doorids';
type SelfToolState = Record<ToggleTool, boolean>;

const mockState: SelfToolState = { godmode: false, invisible: false, playerblips: false, doorids: false };

interface ToolDef {
  id: ToggleTool | 'revive' | 'marker';
  label: string;
  icon: ReactNode;
  toggle: boolean;
}

export function SelfTools({ permissions }: { permissions: Permissions | null }) {
  const toast = useToast();
  const [state, refresh] = useNuiData<SelfToolState>('getSelfToolState', {}, mockState);
  const [busy, setBusy] = useState<string | null>(null);

  const tools: ToolDef[] = [
    { id: 'revive', label: locale('ui_self_revive'), icon: <HeartPulse size={16} />, toggle: false },
    { id: 'marker', label: locale('ui_teleport_to_marker'), icon: <MapPin size={16} />, toggle: false },
    { id: 'godmode', label: locale('ui_godmode'), icon: <Shield size={16} />, toggle: true },
    { id: 'invisible', label: locale('ui_invisible'), icon: <EyeOff size={16} />, toggle: true },
    ...(permissions?.enablePlayerBlips ? [{ id: 'playerblips' as const, label: locale('ui_player_blips'), icon: <Radar size={16} />, toggle: true }] : []),
    { id: 'doorids', label: locale('ui_door_ids'), icon: <DoorOpen size={16} />, toggle: true },
  ];

  const run = async (tool: ToolDef) => {
    setBusy(tool.id);
    const res = await fetchNui<{ success: boolean; enabled?: boolean }>('selfTool', { tool: tool.id }, { success: true, enabled: true });
    setBusy(null);
    if (!res.success) {
      toast.push({ type: 'error', title: locale('ui_action_failed') });
      return;
    }
    if (tool.toggle) refresh();
    else toast.push({ type: 'success', title: tool.label });
  };

  return (
    <div className="rounded-lg p-5" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
      <h3 className="text-[var(--rdr-heading)] text-base font-semibold">{locale('ui_self_tools')}</h3>
      <p className="text-[var(--rdr-muted)] text-xs mt-0.5 mb-4">{locale('ui_self_tools_desc')}</p>
      <div className="grid grid-cols-3 gap-2">
        {tools.map((tool) => {
          const active = tool.toggle && state?.[tool.id as ToggleTool];
          return (
            <button
              key={tool.id}
              type="button"
              disabled={busy !== null}
              onClick={() => run(tool)}
              className={`flex items-center gap-2 px-3 py-2 rounded-sm text-sm border transition-colors disabled:opacity-40 ${
                active
                  ? 'border-[var(--rdr-accent-bright)] bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]'
                  : 'border-[var(--rdr-border)] text-[var(--rdr-text)] hover:bg-white/5 hover:border-[var(--rdr-muted)]'
              }`}
            >
              {tool.icon}
              <span className="flex-1 text-left">{tool.label}</span>
              {tool.toggle && <span className="text-[10px] uppercase tracking-wider">{active ? locale('ui_on') : locale('ui_off')}</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}
