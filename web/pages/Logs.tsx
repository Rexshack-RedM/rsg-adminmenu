import { locale } from '../i18n';
import { useEffect, useState } from 'react';
import { Search, ShieldAlert, Wallet, UserCog, Lock, Server, Cpu, Send } from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Dropdown, type DropdownOption } from '../components/Dropdown';
import { Button } from '../components/Button';
import type { LogCategory, LogEntry, LogsResult } from '../types';

const categoryMeta: Record<LogCategory, { label: string; icon: React.ReactNode; color: string }> = {
  admin_action: { label: locale('ui_admin_action'), icon: <UserCog size={16} />, color: '#e8b25a' },
  economy: { label: locale('ui_economy'), icon: <Wallet size={16} />, color: '#7fc47c' },
  player_action: { label: locale('ui_player_action'), icon: <ShieldAlert size={16} />, color: '#6fa8dc' },
  security: { label: locale('ui_security'), icon: <Lock size={16} />, color: '#e07a6b' },
  server_event: { label: locale('ui_server_event'), icon: <Server size={16} />, color: '#a58fc4' },
  system: { label: locale('ui_system'), icon: <Cpu size={16} />, color: '#b5b5b5' },
};

const categoryFilterOptions: DropdownOption<'all' | LogCategory>[] = [
  { value: 'all', label: locale('ui_all_categories') },
  ...(Object.keys(categoryMeta) as LogCategory[]).map((c) => ({ value: c, label: categoryMeta[c].label })),
];

const severityColors: Record<string, string> = {
  low: 'bg-blue-500/20 text-blue-400',
  medium: 'bg-amber-500/20 text-amber-400',
  high: 'bg-[var(--rdr-red-20)] text-[var(--rdr-red-bright)]',
};

const mockLogs: LogEntry[] = [
  {
    id: 1, category: 'admin_action', severity: 'high', admin_citizenid: 'DEV1234', admin_name: 'Dev Admin',
    action: "Changed player permission level", details: 'Old: mod → New: admin', target_name: 'John Marston',
    ip: '26.204.128.48', created_at: new Date().toISOString(),
  },
  {
    id: 2, category: 'player_action', severity: 'medium', admin_citizenid: 'DEV1234', admin_name: 'Dev Admin',
    action: 'Kicked player', details: 'Reason: RDM near Valentine', target_name: 'Arthur Morgan',
    ip: '26.204.128.48', created_at: new Date(Date.now() - 3600000).toISOString(),
  },
];

const mockResult: LogsResult = {
  logs: mockLogs, total: mockLogs.length, page: 1, perPage: 20,
  counts: { admin_action: 3, economy: 1, player_action: 5, security: 0, server_event: 2, system: 8 },
};

interface LogsProps {
  embedded?: boolean;
  adminCitizenid?: string;
}

export function Logs({ embedded = false, adminCitizenid }: LogsProps) {
  const toast = useToast();
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState<'all' | LogCategory>('all');
  const [page, setPage] = useState(1);

  useEffect(() => { setPage(1); }, [query, category, adminCitizenid]);

  const [data, refresh] = useNuiData<LogsResult>(
    'getLogs',
    { category, search: query, page, adminCitizenid },
    embedded ? mockResult : mockResult
  );

  const result = data ?? mockResult;
  const totalPages = Math.max(1, Math.ceil(result.total / result.perPage));

  const sendToDiscord = async (logId: number) => {
    const res = await fetchNui<{ success: boolean; reason?: string }>('sendLogToDiscord', { logId }, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_sent_to_discord') });
    } else if (res.reason === 'webhook_not_configured') {
      toast.push({ type: 'error', title: locale('ui_no_webhook_configured'), description: locale('ui_set_one_for_this_category_under_master_actio') });
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_send') });
    }
  };

  const list = (
    <div className="space-y-2">
      {result.logs.map((log) => {
        const meta = categoryMeta[log.category] ?? categoryMeta.system;
        return (
          <div key={log.id} className="rounded-sm p-3" style={{ background: 'var(--rdr-surface-2)' }}>
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-start gap-2.5 min-w-0">
                <div className="w-7 h-7 rounded-sm flex items-center justify-center shrink-0" style={{ background: `${meta.color}33`, color: meta.color }}>
                  {meta.icon}
                </div>
                <div className="min-w-0">
                  <p className="text-[var(--rdr-text)] text-sm font-medium truncate">{log.action}</p>
                  {log.details && <p className="text-[var(--rdr-muted)] text-xs mt-0.5 truncate">{log.details}</p>}
                  <p className="text-[var(--rdr-faint)] text-[11px] mt-1">
                    {log.admin_name || locale('ui_system')}{log.target_name ? ` → ${log.target_name}` : ''} · {new Date(log.created_at).toLocaleString()}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-1.5 shrink-0">
                <span className={`px-2 py-0.5 rounded-sm text-[10px] capitalize ${severityColors[log.severity] ?? 'bg-zinc-500/20 text-zinc-400'}`}>{log.severity}</span>
                {!embedded && (
                  <button
                    onClick={() => sendToDiscord(log.id)}
                    title={locale('ui_send_to_discord')}
                    className="text-[var(--rdr-muted)] hover:text-[var(--rdr-accent-bright)] p-1.5 rounded hover:bg-white/5"
                  >
                    <Send size={13} />
                  </button>
                )}
              </div>
            </div>
          </div>
        );
      })}
      {result.logs.length === 0 && (
        <p className="text-[var(--rdr-faint)] text-sm text-center py-8">{locale('ui_no_log_entries_found')}</p>
      )}
    </div>
  );

  if (embedded) {
    return <div className="p-2">{list}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_logs')}</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_full_detailed_history_of_server_and_admin_ac')}</p>
        </div>
        <Button variant="outline" tone="accent" className="text-xs" onClick={() => refresh()}>{locale('ui_refresh')}</Button>
      </div>

      <div className="grid grid-cols-6 gap-3">
        {(Object.keys(categoryMeta) as LogCategory[]).map((c) => (
          <div key={c} className="rounded-lg p-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <div className="w-8 h-8 rounded-lg flex items-center justify-center mb-2" style={{ background: `${categoryMeta[c].color}33`, color: categoryMeta[c].color }}>
              {categoryMeta[c].icon}
            </div>
            <p className="text-lg font-bold" style={{ color: categoryMeta[c].color }}>{result.counts[c] ?? 0}</p>
            <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{categoryMeta[c].label}</p>
          </div>
        ))}
      </div>

      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={locale('ui_search_logs')}
            className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
          />
        </div>
        <Dropdown className="w-44 shrink-0" value={category} onChange={setCategory} options={categoryFilterOptions} />
      </div>

      {list}

      {result.total > 0 && (
        <div className="flex items-center justify-center gap-2 pt-2 pb-4">
          <Button variant="outline" disabled={page <= 1} onClick={() => setPage((p) => p - 1)} className="text-xs px-2.5 py-1.5">{locale('ui_previous')}</Button>
          <span className="text-xs text-[var(--rdr-muted)]">{locale('ui_page_x_of_y', page, totalPages)} ({locale('ui_x_entries', result.total)})</span>
          <Button variant="outline" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)} className="text-xs px-2.5 py-1.5">{locale('ui_next')}</Button>
        </div>
      )}
    </div>
  );
}
