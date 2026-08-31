import { useState } from 'react';
import {
  Search, Plus, Pencil, Trash2, MapPin, Tent, Fish, Gem, Milestone, Store, ShieldAlert,
  TrainFront, Hammer, Coins, Wine, Stethoscope, Users, Cross, Compass, Skull, Crown, Flag,
} from 'lucide-react';
import { fetchNui, useNuiData } from '../../hooks/useNui';
import { useToast } from '../../components/Toast';
import { Modal } from '../../components/Modal';
import { Button } from '../../components/Button';
import type { MapBlip } from '../../types';

// real RDR2 blip texture names only — verified against the game's actual
// texture dictionary (see https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/textures/blips),
// not guessed. A name that doesn't exist in that set hashes to nothing and
// the native blip renders with no icon at all, which is why this list
// previously left most added blips invisible on the map.
// blip_ambient_* sprites are the game's own dynamic/AI marker category (loose
// horses, NPCs, etc.) and RDR3 appears to show their built-in generic hover
// label for these regardless of a custom SetBlipName call — so the default
// preset here is a plain marker (Waypoint), not one of the ambient icons,
// to avoid new admin-placed blips silently getting an unwanted native label
const spritePresets: { sprite: string; label: string; icon: React.ReactNode }[] = [
  { sprite: 'blip_code_waypoint', label: 'Waypoint', icon: <Flag size={18} /> },
  { sprite: 'blip_camp', label: 'Camp', icon: <Tent size={18} /> },
  { sprite: 'blip_mg_fishing', label: 'Fishing', icon: <Fish size={18} /> },
  { sprite: 'blip_chest', label: 'Treasure', icon: <Gem size={18} /> },
  { sprite: 'blip_shop_store', label: 'General Store', icon: <Store size={18} /> },
  { sprite: 'blip_ambient_sheriff', label: 'Sheriff', icon: <ShieldAlert size={18} /> },
  { sprite: 'blip_shop_train', label: 'Train Station', icon: <TrainFront size={18} /> },
  { sprite: 'blip_shop_gunsmith', label: 'Gunsmith', icon: <Hammer size={18} /> },
  { sprite: 'blip_fence_building', label: 'Fence', icon: <Coins size={18} /> },
  { sprite: 'blip_saloon', label: 'Saloon', icon: <Wine size={18} /> },
  { sprite: 'blip_shop_doctor', label: 'Doctor', icon: <Stethoscope size={18} /> },
  { sprite: 'blip_region_hideout', label: 'Gang Hideout', icon: <Users size={18} /> },
  { sprite: 'blip_ambient_death', label: 'Death', icon: <Cross size={18} /> },
  { sprite: 'blip_animal_quality_03', label: 'Legendary Animal', icon: <Compass size={18} /> },
  { sprite: 'blip_animal_dead', label: 'Dead Animal', icon: <Skull size={18} /> },
  { sprite: 'blip_proc_bounty_poster', label: 'Bounty Board', icon: <Crown size={18} /> },
  { sprite: 'blip_ambient_horse', label: 'Horse', icon: <MapPin size={18} /> },
  { sprite: 'blip_ambient_coach', label: 'Coach', icon: <Milestone size={18} /> },
];

const mockBlips: MapBlip[] = [
  { id: 1, name: 'Test Location', sprite: 'blip_ambient_horse', x: -181.2, y: 625.7, z: 114.1, scale: 1, created_by: 'Dev Admin' },
];

export function Blips() {
  const toast = useToast();
  const [data, refresh] = useNuiData<MapBlip[]>('getBlips', {}, mockBlips);
  const blips = data ?? [];
  const [query, setQuery] = useState('');
  const [editing, setEditing] = useState<MapBlip | 'new' | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<MapBlip | null>(null);

  const filtered = blips.filter((b) => b.name.toLowerCase().includes(query.toLowerCase()));

  const remove = async () => {
    if (!deleteTarget) return;
    const res = await fetchNui<{ success: boolean }>('deleteBlip', { id: deleteTarget.id }, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: 'Blip deleted' });
      setDeleteTarget(null);
      refresh();
    } else {
      toast.push({ type: 'error', title: 'Failed to delete blip' });
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">Blip Manager</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">Manage map blips and markers</p>
        </div>
        <Button variant="outline" tone="green" className="text-xs" onClick={() => setEditing('new')}>
          <Plus size={13} /> Add Blip
        </Button>
      </div>

      <div className="relative">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search blips..."
          className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
        />
      </div>
      <p className="text-[var(--rdr-faint)] text-xs">Showing {filtered.length} blip{filtered.length === 1 ? '' : 's'}</p>

      <div className="grid grid-cols-3 gap-3">
        {filtered.map((b) => (
          <div key={b.id} className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-sm flex items-center justify-center shrink-0 bg-[var(--rdr-surface-2)] text-[var(--rdr-text)]">
                {spritePresets.find((s) => s.sprite === b.sprite)?.icon ?? <MapPin size={18} />}
              </div>
              <div className="min-w-0">
                <p className="text-[var(--rdr-heading)] text-sm font-semibold truncate">{b.name}</p>
                <p className="text-[var(--rdr-faint)] text-[11px] truncate">{b.sprite}</p>
              </div>
            </div>
            <div className="mt-3 text-xs text-[var(--rdr-muted)] space-y-1">
              <p>Coordinates: <span className="text-[var(--rdr-text)]">{b.x.toFixed(1)}, {b.y.toFixed(1)}, {b.z.toFixed(1)}</span></p>
              <p>Scale: <span className="text-[var(--rdr-text)]">{b.scale}x</span></p>
            </div>
            <div className="flex gap-2 mt-3">
              <Button variant="outline" fullWidth className="text-xs" onClick={() => setEditing(b)}><Pencil size={13} /> Edit</Button>
              <Button variant="outline" tone="red" fullWidth className="text-xs" onClick={() => setDeleteTarget(b)}><Trash2 size={13} /> Delete</Button>
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <p className="col-span-3 text-center text-[var(--rdr-faint)] text-sm py-8">No blips found</p>
        )}
      </div>

      {editing && (
        <BlipFormModal
          blip={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => { setEditing(null); refresh(); }}
        />
      )}

      {deleteTarget && (
        <Modal title="Delete Blip" onClose={() => setDeleteTarget(null)} width="max-w-sm">
          <p className="text-[var(--rdr-text)] text-sm mb-5">Delete "{deleteTarget.name}"? This cannot be undone.</p>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDeleteTarget(null)}>Cancel</Button>
            <Button variant="solid" tone="red" onClick={remove}>Delete</Button>
          </div>
        </Modal>
      )}
    </div>
  );
}

const inputCls = 'w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]';

function BlipFormModal({ blip, onClose, onSaved }: { blip: MapBlip | null; onClose: () => void; onSaved: () => void }) {
  const toast = useToast();
  const [name, setName] = useState(blip?.name ?? '');
  const [sprite, setSprite] = useState(blip?.sprite ?? spritePresets[0].sprite);
  const [scale, setScale] = useState<number | ''>(blip?.scale ?? 1);
  const [x, setX] = useState<number | ''>(blip?.x ?? '');
  const [y, setY] = useState<number | ''>(blip?.y ?? '');
  const [z, setZ] = useState<number | ''>(blip?.z ?? 0);

  const valid = name.trim().length > 0 && sprite.trim().length > 0 && x !== '' && y !== '';

  const useCurrentLocation = async () => {
    const coords = await fetchNui<{ x: number; y: number; z: number; heading: number }>('getCurrentCoords', {}, { x: 0, y: 0, z: 0, heading: 0 });
    setX(Number(coords.x.toFixed(2)));
    setY(Number(coords.y.toFixed(2)));
    setZ(Number(coords.z.toFixed(2)));
  };

  const submit = async () => {
    if (!valid) return;
    const payload = { id: blip?.id, name: name.trim(), sprite: sprite.trim(), x: Number(x), y: Number(y), z: Number(z) || 0, scale: Number(scale) || 1 };
    const res = await fetchNui<{ success: boolean }>(blip ? 'updateBlip' : 'addBlip', payload, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: blip ? 'Blip updated' : 'Blip added' });
      onSaved();
    } else {
      toast.push({ type: 'error', title: 'Failed to save blip' });
    }
  };

  return (
    <Modal title={blip ? 'Edit Blip' : 'Add Blip'} onClose={onClose} width="max-w-lg">
        <div className="space-y-3">
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Blip Name *</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className={inputCls} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Select Blip Icon *</label>
            <div className="grid grid-cols-8 gap-1.5 mt-1 max-h-40 overflow-y-auto p-1">
              {spritePresets.map((s) => (
                <button
                  key={s.sprite}
                  title={s.label}
                  onClick={() => setSprite(s.sprite)}
                  className={`aspect-square rounded-sm flex items-center justify-center transition-colors ${sprite === s.sprite ? 'bg-white/10 border border-[var(--rdr-heading)]' : 'bg-[var(--rdr-surface-2)] border border-transparent hover:border-[var(--rdr-border)]'}`}
                >
                  {s.icon}
                </button>
              ))}
            </div>
            <input value={sprite} onChange={(e) => setSprite(e.target.value)} placeholder="Sprite name (advanced)" className={`${inputCls} text-xs`} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Scale</label>
            <input type="number" step="0.1" min={0.1} value={scale} onChange={(e) => setScale(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
          </div>
          <div>
            <div className="flex items-center justify-between">
              <label className="text-xs text-[var(--rdr-muted)]">Coordinates *</label>
              <Button variant="outline" className="text-[11px] px-2 py-1" onClick={useCurrentLocation}>Use Current Location</Button>
            </div>
            <div className="grid grid-cols-3 gap-3 mt-1">
              <input type="number" placeholder="X" value={x} onChange={(e) => setX(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
              <input type="number" placeholder="Y" value={y} onChange={(e) => setY(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
              <input type="number" placeholder="Z" value={z} onChange={(e) => setZ(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={onClose}>Cancel</Button>
            <Button variant="solid" tone="accent" disabled={!valid} onClick={submit}>{blip ? 'Update Blip' : 'Add Blip'}</Button>
          </div>
        </div>
      </Modal>
  );
}
