import { locale } from '../../i18n';
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
  { sprite: 'blip_code_waypoint', label: locale('ui_waypoint'), icon: <Flag size={18} /> },
  { sprite: 'blip_camp', label: locale('ui_camp'), icon: <Tent size={18} /> },
  { sprite: 'blip_mg_fishing', label: locale('ui_fishing'), icon: <Fish size={18} /> },
  { sprite: 'blip_chest', label: locale('ui_treasure'), icon: <Gem size={18} /> },
  { sprite: 'blip_shop_store', label: locale('ui_general_store'), icon: <Store size={18} /> },
  { sprite: 'blip_ambient_sheriff', label: locale('ui_sheriff'), icon: <ShieldAlert size={18} /> },
  { sprite: 'blip_shop_train', label: locale('ui_train_station'), icon: <TrainFront size={18} /> },
  { sprite: 'blip_shop_gunsmith', label: locale('ui_gunsmith'), icon: <Hammer size={18} /> },
  { sprite: 'blip_fence_building', label: locale('ui_fence'), icon: <Coins size={18} /> },
  { sprite: 'blip_saloon', label: locale('ui_saloon'), icon: <Wine size={18} /> },
  { sprite: 'blip_shop_doctor', label: locale('ui_doctor'), icon: <Stethoscope size={18} /> },
  { sprite: 'blip_region_hideout', label: locale('ui_gang_hideout'), icon: <Users size={18} /> },
  { sprite: 'blip_ambient_death', label: locale('ui_death'), icon: <Cross size={18} /> },
  { sprite: 'blip_animal_quality_03', label: locale('ui_legendary_animal'), icon: <Compass size={18} /> },
  { sprite: 'blip_animal_dead', label: locale('ui_dead_animal'), icon: <Skull size={18} /> },
  { sprite: 'blip_proc_bounty_poster', label: locale('ui_bounty_board'), icon: <Crown size={18} /> },
  { sprite: 'blip_ambient_horse', label: locale('ui_horse'), icon: <MapPin size={18} /> },
  { sprite: 'blip_ambient_coach', label: locale('ui_coach'), icon: <Milestone size={18} /> },
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
      toast.push({ type: 'success', title: locale('ui_blip_deleted') });
      setDeleteTarget(null);
      refresh();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_delete_blip') });
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_blip_manager')}</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_manage_map_blips_and_markers')}</p>
        </div>
        <Button variant="outline" tone="green" className="text-xs" onClick={() => setEditing('new')}>
          <Plus size={13} /> {locale('ui_add_blip')}
        </Button>
      </div>

      <div className="relative">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={locale('ui_search_blips')}
          className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
        />
      </div>
      <p className="text-[var(--rdr-faint)] text-xs">{locale('ui_showing_x_blips', filtered.length)}</p>

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
              <p>{locale('ui_coordinates_2')} <span className="text-[var(--rdr-text)]">{b.x.toFixed(1)}, {b.y.toFixed(1)}, {b.z.toFixed(1)}</span></p>
              <p>{locale('ui_scale_2')} <span className="text-[var(--rdr-text)]">{b.scale}x</span></p>
            </div>
            <div className="flex gap-2 mt-3">
              <Button variant="outline" fullWidth className="text-xs" onClick={() => setEditing(b)}><Pencil size={13} /> {locale('ui_edit')}</Button>
              <Button variant="outline" tone="red" fullWidth className="text-xs" onClick={() => setDeleteTarget(b)}><Trash2 size={13} /> {locale('ui_delete')}</Button>
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <p className="col-span-3 text-center text-[var(--rdr-faint)] text-sm py-8">{locale('ui_no_blips_found')}</p>
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
        <Modal title={locale('ui_delete_blip')} onClose={() => setDeleteTarget(null)} width="max-w-sm">
          <p className="text-[var(--rdr-text)] text-sm mb-5">{locale('ui_delete_x_confirm', deleteTarget.name)}</p>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDeleteTarget(null)}>{locale('ui_cancel')}</Button>
            <Button variant="solid" tone="red" onClick={remove}>{locale('ui_delete')}</Button>
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
      toast.push({ type: 'success', title: blip ? locale('ui_blip_updated') : locale('ui_blip_added') });
      onSaved();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_save_blip') });
    }
  };

  return (
    <Modal title={blip ? locale('ui_edit_blip') : locale('ui_add_blip')} onClose={onClose} width="max-w-lg">
        <div className="space-y-3">
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_blip_name')}</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className={inputCls} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_select_blip_icon')}</label>
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
            <input value={sprite} onChange={(e) => setSprite(e.target.value)} placeholder={locale('ui_sprite_name_advanced')} className={`${inputCls} text-xs`} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_scale')}</label>
            <input type="number" step="0.1" min={0.1} value={scale} onChange={(e) => setScale(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
          </div>
          <div>
            <div className="flex items-center justify-between">
              <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_coordinates')}</label>
              <Button variant="outline" className="text-[11px] px-2 py-1" onClick={useCurrentLocation}>{locale('ui_use_current_location')}</Button>
            </div>
            <div className="grid grid-cols-3 gap-3 mt-1">
              <input type="number" placeholder="X" value={x} onChange={(e) => setX(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
              <input type="number" placeholder="Y" value={y} onChange={(e) => setY(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
              <input type="number" placeholder="Z" value={z} onChange={(e) => setZ(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={onClose}>{locale('ui_cancel')}</Button>
            <Button variant="solid" tone="accent" disabled={!valid} onClick={submit}>{blip ? locale('ui_update_blip') : locale('ui_add_blip')}</Button>
          </div>
        </div>
      </Modal>
  );
}
