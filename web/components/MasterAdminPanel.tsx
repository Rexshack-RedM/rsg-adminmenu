import { useEffect, useState } from 'react';
import { Webhook } from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from './Toast';
import { Button } from './Button';
import type { WebhookSettings } from '../types';

const mockWebhooks: WebhookSettings = {
  adminLogs: 'YOUR_WEBHOOK_URL_HERE',
  playerManagement: 'YOUR_WEBHOOK_URL_HERE',
  worldSettings: 'YOUR_WEBHOOK_URL_HERE',
  reports: 'YOUR_WEBHOOK_URL_HERE',
};

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

const inputCls = 'w-full bg-[var(--rdr-surface-2)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]';

export function MasterAdminPanel() {
  const toast = useToast();
  const [remote, refreshWebhooks] = useNuiData<WebhookSettings>('getWebhookSettings', {}, mockWebhooks);
  const [webhooks, setWebhooks] = useState<WebhookSettings>(mockWebhooks);
  const [saving, setSaving] = useState(false);

  useEffect(() => { if (remote) setWebhooks(remote); }, [remote]);

  const saveWebhooks = async () => {
    setSaving(true);
    const res = await fetchNui<{ success: boolean }>('saveWebhookSettings', webhooks, { success: true });
    setSaving(false);
    if (res.success) {
      toast.push({ type: 'success', title: 'Webhook settings saved' });
      refreshWebhooks();
    } else {
      toast.push({ type: 'error', title: 'Failed to save webhook settings' });
    }
  };

  return (
    <div className="space-y-4">
      <Panel icon={<Webhook size={16} />} title="Webhook Configuration" description="Route different log categories to their own Discord channels">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Admin Logs</label>
            <input className={`${inputCls} mt-1`} placeholder="https://discord.com/api/webhooks/..." value={webhooks.adminLogs} onChange={(e) => setWebhooks((w) => ({ ...w, adminLogs: e.target.value }))} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Reports</label>
            <input className={`${inputCls} mt-1`} placeholder="https://discord.com/api/webhooks/..." value={webhooks.reports} onChange={(e) => setWebhooks((w) => ({ ...w, reports: e.target.value }))} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Player Management (incl. Finances)</label>
            <input className={`${inputCls} mt-1`} placeholder="https://discord.com/api/webhooks/..." value={webhooks.playerManagement} onChange={(e) => setWebhooks((w) => ({ ...w, playerManagement: e.target.value }))} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">World Settings</label>
            <input className={`${inputCls} mt-1`} placeholder="https://discord.com/api/webhooks/..." value={webhooks.worldSettings} onChange={(e) => setWebhooks((w) => ({ ...w, worldSettings: e.target.value }))} />
          </div>
        </div>
        <p className="text-[var(--rdr-faint)] text-[11px]">These can also be edited directly in config.lua (Config.Webhooks / Config.Reports.Webhooks.Main). Whichever was saved most recently wins.</p>
        <Button variant="solid" tone="accent" isLoading={saving} onClick={saveWebhooks}>Save Webhook Settings</Button>
      </Panel>
    </div>
  );
}
