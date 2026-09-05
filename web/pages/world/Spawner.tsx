import { useState } from 'react';
import { Sparkles, Truck, PawPrint, Box, User, Info, Trash2 } from 'lucide-react';
import { fetchNui } from '../../hooks/useNui';
import { useToast } from '../../components/Toast';
import { Modal } from '../../components/Modal';
import { Button } from '../../components/Button';

type EntityType = 'wagon' | 'animal' | 'prop' | 'ped';

const spawnCards: { type: EntityType; label: string; desc: string; icon: React.ReactNode; example: string }[] = [
  { type: 'wagon', label: 'Spawn Wagon', desc: 'Spawn a wagon using its hash', icon: <Truck size={20} />, example: 'cart01' },
  { type: 'animal', label: 'Spawn Animal', desc: 'Spawn a horse or any other animal using its hash', icon: <PawPrint size={20} />, example: 'a_c_deer_01' },
  { type: 'prop', label: 'Spawn Prop', desc: 'Spawn a prop/object using its hash', icon: <Box size={20} />, example: 'p_chair01x' },
  { type: 'ped', label: 'Spawn Ped', desc: 'Spawn a ped/NPC using its hash', icon: <User size={20} />, example: 'a_m_m_valtownfolk_01' },
];

export function Spawner() {
  const toast = useToast();
  const [open, setOpen] = useState<EntityType | null>(null);
  const [hash, setHash] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [showClear, setShowClear] = useState(false);
  const [radius, setRadius] = useState(25);
  const [clearing, setClearing] = useState(false);

  const submit = async () => {
    if (!open || !hash.trim()) return;
    setSubmitting(true);
    const res = await fetchNui<{ success: boolean; message?: string }>('spawnEntity', { entityType: open, hash: hash.trim() }, { success: true });
    setSubmitting(false);
    if (res.success) {
      toast.push({ type: 'success', title: 'Spawn requested' });
      setOpen(null);
      setHash('');
    } else {
      toast.push({ type: 'error', title: 'Failed to spawn', description: res.message });
    }
  };

  const clearArea = async () => {
    const r = Math.min(100, Math.max(5, Number(radius) || 25));
    setClearing(true);
    const res = await fetchNui<{ success: boolean; message?: string }>('clearArea', { radius: r }, { success: true });
    setClearing(false);
    if (res.success) {
      toast.push({ type: 'success', title: `Clearing entities within ${r}m` });
      setShowClear(false);
    } else {
      toast.push({ type: 'error', title: 'Failed to clear area', description: res.message });
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><Sparkles size={22} /> Entity Spawner</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">Spawn vehicles, animals, props, and peds using their hash names</p>
      </div>

      <div className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">
            <Trash2 size={20} />
          </div>
          <div>
            <p className="text-[var(--rdr-heading)] text-sm font-semibold">Clear Area</p>
            <p className="text-[var(--rdr-muted)] text-xs mt-0.5">Remove spawned peds, props, and unridden horses around you</p>
          </div>
        </div>
        <Button variant="outline" tone="red" fullWidth className="mt-3" onClick={() => setShowClear(true)}>
          <Trash2 size={14} /> Clear Area
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {spawnCards.map((c) => (
          <div key={c.type} className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">
                {c.icon}
              </div>
              <div>
                <p className="text-[var(--rdr-heading)] text-sm font-semibold">{c.label}</p>
                <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{c.desc}</p>
              </div>
            </div>
            <Button variant="outline" tone="accent" fullWidth className="mt-3" onClick={() => { setOpen(c.type); setHash(''); }}>
              <Sparkles size={14} /> Spawn
            </Button>
          </div>
        ))}
      </div>

      <div className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <p className="text-[var(--rdr-heading)] text-sm font-semibold flex items-center gap-2 mb-2"><Info size={15} /> Usage Tips</p>
        <ul className="text-[var(--rdr-muted)] text-xs space-y-1 list-disc list-inside">
          <li>Enter the exact hash name of the entity you want to spawn</li>
          <li>Entities will spawn near your current position</li>
          <li>Make sure the hash name is valid for RedM</li>
          <li>Examples: cart01, a_c_deer_01, a_c_horse_arabian_white, p_chair01x, a_m_m_valtownfolk_01</li>
        </ul>
      </div>

      {open && (
        <Modal title={spawnCards.find((c) => c.type === open)?.label ?? 'Spawn Entity'} subtitle={spawnCards.find((c) => c.type === open)?.desc} onClose={() => setOpen(null)} width="max-w-sm">
          <div className="space-y-3">
            <div>
              <label className="text-xs text-[var(--rdr-muted)]">Hash Name</label>
              <input
                autoFocus
                value={hash}
                onChange={(e) => setHash(e.target.value)}
                placeholder={`e.g., ${spawnCards.find((c) => c.type === open)?.example}`}
                className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]"
              />
              <p className="text-[var(--rdr-faint)] text-[11px] mt-1">Enter the exact hash name of the entity</p>
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setOpen(null)}>Cancel</Button>
              <Button variant="solid" tone="accent" disabled={!hash.trim() || submitting} isLoading={submitting} onClick={submit}>
                <Sparkles size={14} /> Spawn
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {showClear && (
        <Modal title="Clear Area" subtitle="Remove spawned entities around you" onClose={() => setShowClear(false)} width="max-w-sm">
          <div className="space-y-3">
            <div>
              <label className="text-xs text-[var(--rdr-muted)]">Radius (metres)</label>
              <input
                autoFocus
                type="number"
                min={5}
                max={100}
                value={radius}
                onChange={(e) => setRadius(Number(e.target.value))}
                className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]"
              />
              <p className="text-[var(--rdr-faint)] text-[11px] mt-1">
                Clears NPCs, animals, unridden horses, and spawned props. Players, horses being ridden, and default map objects are left alone.
              </p>
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setShowClear(false)}>Cancel</Button>
              <Button variant="solid" tone="red" disabled={clearing} isLoading={clearing} onClick={clearArea}>
                <Trash2 size={14} /> Clear Area
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
