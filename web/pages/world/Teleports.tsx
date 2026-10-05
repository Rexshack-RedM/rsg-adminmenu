import { locale } from '../../i18n';
import { useMemo, useState } from 'react';
import { Search, MapPinned, Navigation, Plus, Trash2, Star } from 'lucide-react';
import { fetchNui, useNuiData } from '../../hooks/useNui';
import { useToast } from '../../components/Toast';
import { Modal } from '../../components/Modal';
import { Dropdown, type DropdownOption } from '../../components/Dropdown';
import { Button } from '../../components/Button';
import { builtInLocations, categoryIcons, categoryLabels } from '../../data/worldLocations';
import type { Permissions, TeleportCategory, TeleportLocation } from '../../types';

const categoryFilterOptions: DropdownOption<'all' | TeleportCategory>[] = [
  { value: 'all', label: locale('ui_all_categories') },
  ...(Object.keys(categoryLabels) as TeleportCategory[]).map((c) => ({ value: c, label: categoryLabels[c] })),
];

export function Teleports({ permissions }: { permissions: Permissions | null }) {
  const toast = useToast();
  const canManage = permissions?.atLeastMod ?? false;
  const [customData, refresh] = useNuiData<TeleportLocation[]>('getTeleportLocations', {}, []);
  const locations = useMemo(() => [...builtInLocations, ...(customData ?? []).map((l) => ({ ...l, custom: true }))], [customData]);

  const [query, setQuery] = useState('');
  const [category, setCategory] = useState<'all' | TeleportCategory>('all');
  const [showCustom, setShowCustom] = useState(false);
  const [showAdd, setShowAdd] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<TeleportLocation | null>(null);

  const counts = useMemo(() => {
    const c: Record<TeleportCategory, number> = { towns: 0, gangcamps: 0, nature: 0, shops: 0, special: 0 };
    for (const l of locations) c[l.category]++;
    return c;
  }, [locations]);

  const popular = locations.filter((l) => l.popular).slice(0, 8);

  const filtered = locations.filter((l) => {
    if (category !== 'all' && l.category !== category) return false;
    if (query && !l.name.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  });

  const teleport = async (loc: TeleportLocation) => {
    await fetchNui('teleportToCoords', { x: loc.x, y: loc.y, z: loc.z, heading: loc.heading }, { success: true });
    toast.push({ type: 'success', title: locale('ui_teleported_to_x', loc.name) });
  };

  const deleteCustom = async () => {
    if (!deleteTarget) return;
    const res = await fetchNui<{ success: boolean }>('deleteTeleportLocation', { id: deleteTarget.id }, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_location_deleted') });
      setDeleteTarget(null);
      refresh();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_delete_location') });
    }
  };

  return (
    <div className="space-y-4 pb-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">{locale('ui_teleports')}</h2>
          <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_jump_to_any_saved_location_or_teleport_to_ex')}</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" tone="accent" className="text-xs" onClick={() => setShowCustom(true)}>
            <Navigation size={13} /> {locale('ui_custom_teleport')}
          </Button>
          {canManage && (
            <Button variant="outline" tone="green" className="text-xs" onClick={() => setShowAdd(true)}>
              <Plus size={13} /> {locale('ui_add_location')}
            </Button>
          )}
        </div>
      </div>

      <div className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <p className="text-[var(--rdr-muted)] text-xs uppercase tracking-wider font-medium mb-3 flex items-center gap-1.5"><MapPinned size={13} /> {locale('ui_quick_access_locations')}</p>
        <div className="grid grid-cols-4 gap-2">
          {popular.map((loc) => (
            <button
              key={loc.id}
              onClick={() => teleport(loc)}
              className="flex flex-col items-center gap-1.5 p-3 rounded-sm text-center transition-colors hover:bg-white/5"
              style={{ background: 'var(--rdr-surface-2)', border: '1px solid var(--rdr-border)' }}
            >
              <span className="text-xl">{categoryIcons[loc.category]}</span>
              <span className="text-xs font-medium text-[var(--rdr-text)]">{loc.name}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-5 gap-3">
        {(Object.keys(categoryLabels) as TeleportCategory[]).map((c) => (
          <div key={c} className="rounded-lg p-3 text-center" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <p className="text-xl">{categoryIcons[c]}</p>
            <p className="text-[var(--rdr-heading)] text-lg font-bold mt-1">{counts[c]}</p>
            <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{categoryLabels[c]}</p>
          </div>
        ))}
      </div>

      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--rdr-faint)]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={locale('ui_search_locations')}
            className="w-full pl-9 pr-3 py-2 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm text-sm text-[var(--rdr-text)]"
          />
        </div>
        <Dropdown className="w-48 shrink-0" value={category} onChange={setCategory} options={categoryFilterOptions} />
      </div>

      <div className="grid grid-cols-3 gap-3">
        {filtered.map((loc) => (
          <div key={loc.id} className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-center gap-2 min-w-0">
                <span className="text-lg shrink-0">{categoryIcons[loc.category]}</span>
                <div className="min-w-0">
                  <p className="text-[var(--rdr-heading)] text-sm font-semibold truncate">{loc.name}</p>
                  <span className="text-[10px] text-[var(--rdr-faint)]">{categoryLabels[loc.category]}</span>
                </div>
              </div>
              {loc.popular && <span className="px-1.5 py-0.5 rounded-sm text-[10px] font-semibold bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)] flex items-center gap-0.5 shrink-0"><Star size={10} /> {locale('ui_popular')}</span>}
            </div>
            {loc.description && <p className="text-[var(--rdr-muted)] text-xs mt-2">{loc.description}</p>}
            <div className="rounded-sm p-2 mt-3 grid grid-cols-2 gap-1 text-[11px]" style={{ background: 'var(--rdr-surface-2)' }}>
              <span className="text-[var(--rdr-faint)]">X: <span className="text-[var(--rdr-text)]">{loc.x.toFixed(1)}</span></span>
              <span className="text-[var(--rdr-faint)]">Y: <span className="text-[var(--rdr-text)]">{loc.y.toFixed(1)}</span></span>
              <span className="text-[var(--rdr-faint)]">Z: <span className="text-[var(--rdr-text)]">{loc.z.toFixed(1)}</span></span>
              <span className="text-[var(--rdr-faint)]">H: <span className="text-[var(--rdr-text)]">{loc.heading.toFixed(0)}</span></span>
            </div>
            <div className="flex gap-2 mt-3">
              <Button variant="outline" tone="accent" fullWidth className="text-xs" onClick={() => teleport(loc)}>
                <Navigation size={13} /> {locale('ui_teleport')}
              </Button>
              {canManage && loc.custom && (
                <Button variant="outline" tone="red" className="text-xs px-2.5" onClick={() => setDeleteTarget(loc)}>
                  <Trash2 size={13} />
                </Button>
              )}
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <p className="col-span-3 text-center text-[var(--rdr-faint)] text-sm py-8">{locale('ui_no_locations_found')}</p>
        )}
      </div>

      {showCustom && <CustomTeleportModal onClose={() => setShowCustom(false)} onDone={() => { toast.push({ type: 'success', title: locale('ui_teleported') }); setShowCustom(false); }} />}
      {showAdd && <AddLocationModal onClose={() => setShowAdd(false)} onAdded={() => { setShowAdd(false); refresh(); }} />}

      {deleteTarget && (
        <Modal title={locale('ui_delete_location')} onClose={() => setDeleteTarget(null)} width="max-w-sm">
          <p className="text-[var(--rdr-text)] text-sm mb-5">{locale('ui_delete_x_confirm', deleteTarget.name)}</p>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDeleteTarget(null)}>{locale('ui_cancel')}</Button>
            <Button variant="solid" tone="red" onClick={deleteCustom}>{locale('ui_delete')}</Button>
          </div>
        </Modal>
      )}
    </div>
  );
}

const inputCls = 'w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]';

function CustomTeleportModal({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const [x, setX] = useState<number | ''>('');
  const [y, setY] = useState<number | ''>('');
  const [z, setZ] = useState<number | ''>('');
  const [heading, setHeading] = useState<number | ''>(0);

  const valid = x !== '' && y !== '' && z !== '';

  const submit = async () => {
    if (!valid) return;
    await fetchNui('teleportToCoords', { x: Number(x), y: Number(y), z: Number(z), heading: Number(heading) || 0 }, { success: true });
    onDone();
  };

  return (
    <Modal title={locale('ui_custom_teleport')} subtitle={locale('ui_teleport_to_specific_coordinates')} onClose={onClose} width="max-w-sm">
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_x_coordinate')}</label>
          <input type="number" value={x} onChange={(e) => setX(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_y_coordinate')}</label>
          <input type="number" value={y} onChange={(e) => setY(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_z_coordinate')}</label>
          <input type="number" value={z} onChange={(e) => setZ(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_heading_optional')}</label>
          <input type="number" value={heading} onChange={(e) => setHeading(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
        </div>
      </div>
      <div className="flex justify-end gap-2 mt-4">
        <Button variant="ghost" onClick={onClose}>{locale('ui_cancel')}</Button>
        <Button variant="solid" tone="accent" disabled={!valid} onClick={submit}><Navigation size={13} /> {locale('ui_teleport')}</Button>
      </div>
    </Modal>
  );
}

const addCategoryOptions = (Object.keys(categoryLabels) as TeleportCategory[]).map((c) => ({ value: c, label: categoryLabels[c] }));

function AddLocationModal({ onClose, onAdded }: { onClose: () => void; onAdded: () => void }) {
  const toast = useToast();
  const [name, setName] = useState('');
  const [category, setCategory] = useState<TeleportCategory>('special');
  const [x, setX] = useState<number | ''>('');
  const [y, setY] = useState<number | ''>('');
  const [z, setZ] = useState<number | ''>('');
  const [heading, setHeading] = useState<number | ''>(0);

  const valid = name.trim().length > 0 && x !== '' && y !== '' && z !== '';

  const useCurrentLocation = async () => {
    const coords = await fetchNui<{ x: number; y: number; z: number; heading: number }>('getCurrentCoords', {}, { x: 0, y: 0, z: 0, heading: 0 });
    setX(Number(coords.x.toFixed(2)));
    setY(Number(coords.y.toFixed(2)));
    setZ(Number(coords.z.toFixed(2)));
    setHeading(Number(coords.heading.toFixed(1)));
  };

  const submit = async () => {
    if (!valid) return;
    const res = await fetchNui<{ success: boolean }>('addTeleportLocation', {
      name: name.trim(), category, x: Number(x), y: Number(y), z: Number(z), heading: Number(heading) || 0,
    }, { success: true });
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_location_added') });
      onAdded();
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_add_location') });
    }
  };

  return (
    <Modal title={locale('ui_add_new_location')} subtitle={locale('ui_save_a_new_teleport_location')} onClose={onClose} width="max-w-sm">
      <div className="space-y-3">
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_location_name')}</label>
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder={locale('ui_e_g_custom_shop')} className={inputCls} />
        </div>
        <div>
          <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_category')}</label>
          <div className="mt-1"><Dropdown value={category} onChange={setCategory} options={addCategoryOptions} /></div>
        </div>
        <Button variant="outline" fullWidth className="text-xs" onClick={useCurrentLocation}>{locale('ui_use_current_location')}</Button>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">X</label>
            <input type="number" value={x} onChange={(e) => setX(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Y</label>
            <input type="number" value={y} onChange={(e) => setY(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">Z</label>
            <input type="number" value={z} onChange={(e) => setZ(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
          </div>
          <div>
            <label className="text-xs text-[var(--rdr-muted)]">H</label>
            <input type="number" value={heading} onChange={(e) => setHeading(e.target.value === '' ? '' : Number(e.target.value))} className={inputCls} />
          </div>
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>{locale('ui_cancel')}</Button>
          <Button variant="solid" tone="green" disabled={!valid} onClick={submit}><Plus size={13} /> {locale('ui_add_location')}</Button>
        </div>
      </div>
    </Modal>
  );
}
