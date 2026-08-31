import { useState } from 'react';
import { fetchNui } from '../../hooks/useNui';
import { useToast } from '../../components/Toast';
import { Button } from '../../components/Button';
import { Dropdown } from '../../components/Dropdown';
import type { ReportSeverity, ReportType } from '../../types';

const types: { value: ReportType; label: string; desc: string }[] = [
  { value: 'bug', label: 'Bug Report', desc: 'Something in the game is broken' },
  { value: 'player', label: 'Player Report', desc: 'Report another player' },
  { value: 'question', label: 'General Question', desc: 'Ask staff a question' },
];

const severityOptions: { value: ReportSeverity; label: string }[] = [
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
];

export function CreateReport({ onCreated }: { onCreated: () => void }) {
  const toast = useToast();
  const [type, setType] = useState<ReportType | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [reportedPlayerId, setReportedPlayerId] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [severity, setSeverity] = useState<ReportSeverity>('medium');
  const [submitting, setSubmitting] = useState(false);

  const valid = title.trim().length >= 5 && title.trim().length <= 100 && description.trim().length >= 10 && description.trim().length <= 500;

  const submit = async () => {
    if (!type || !valid) return;
    setSubmitting(true);
    const res = await fetchNui<{ success: boolean; message?: string }>('createReport', {
      reportType: type,
      title: title.trim(),
      description: description.trim(),
      reportedPlayerId: type === 'player' && reportedPlayerId ? Number(reportedPlayerId) : undefined,
      imageUrl: imageUrl.trim() || undefined,
      severity,
    }, { success: true });
    setSubmitting(false);
    if (res.success) {
      toast.push({ type: 'success', title: 'Report submitted' });
      setType(null); setTitle(''); setDescription(''); setReportedPlayerId(''); setImageUrl(''); setSeverity('medium');
      onCreated();
    } else {
      toast.push({ type: 'error', title: 'Failed to submit', description: res.message });
    }
  };

  if (!type) {
    return (
      <div className="space-y-3">
        <h3 className="text-[var(--rdr-heading)] text-base font-semibold" style={{ fontFamily: 'var(--font-display)' }}>Select Report Type</h3>
        <div className="grid gap-2">
          {types.map((t) => (
            <button
              key={t.value}
              onClick={() => setType(t.value)}
              className="text-left px-4 py-3 rounded-sm bg-[var(--rdr-surface)] border border-[var(--rdr-border)] hover:border-[var(--rdr-accent)]"
            >
              <p className="text-[var(--rdr-text)] text-sm font-medium">{t.label}</p>
              <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{t.desc}</p>
            </button>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-3 max-w-md">
      <Button variant="ghost" tone="accent" className="text-xs px-2 py-1" onClick={() => setType(null)}>&larr; back</Button>
      <h3 className="text-[var(--rdr-heading)] text-base font-semibold" style={{ fontFamily: 'var(--font-display)' }}>
        {types.find((t) => t.value === type)?.label}
      </h3>

      <div>
        <label className="text-xs text-[var(--rdr-muted)]">Report Title</label>
        <input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={100} className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
      </div>
      <div>
        <label className="text-xs text-[var(--rdr-muted)]">Description</label>
        <textarea value={description} onChange={(e) => setDescription(e.target.value)} maxLength={500} rows={4} className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
      </div>
      <div>
        <label className="text-xs text-[var(--rdr-muted)]">Severity</label>
        <div className="mt-1"><Dropdown value={severity} onChange={setSeverity} options={severityOptions} /></div>
      </div>
      {type === 'player' && (
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Player Server ID (optional)</label>
          <input value={reportedPlayerId} onChange={(e) => setReportedPlayerId(e.target.value.replace(/\D/g, ''))} className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
      )}
      {type !== 'question' && (
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">Image URL (optional)</label>
          <input value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} placeholder="Imgur / Discord CDN / Gyazo link" className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
        </div>
      )}
      <Button variant="solid" tone="accent" fullWidth disabled={!valid || submitting} onClick={submit}>
        Submit Report
      </Button>
    </div>
  );
}
