import { locale } from '../../i18n';
import { useState } from 'react';
import { Sparkles, Truck, PawPrint, Box, User, Info, Trash2 } from 'lucide-react';
import { fetchNui } from '../../hooks/useNui';
import { useToast } from '../../components/Toast';
import { Modal } from '../../components/Modal';
import { Button } from '../../components/Button';

type EntityType = 'wagon' | 'animal' | 'prop' | 'ped';

const spawnCards: { type: EntityType; label: string; desc: string; icon: React.ReactNode; example: string }[] = [
  { type: 'wagon', label: locale('ui_spawn_wagon'), desc: locale('ui_spawn_a_wagon_using_its_hash'), icon: <Truck size={20} />, example: 'cart01' },
  { type: 'animal', label: locale('ui_spawn_animal'), desc: locale('ui_spawn_a_horse_or_any_other_animal_using_its'), icon: <PawPrint size={20} />, example: 'a_c_deer_01' },
  { type: 'prop', label: locale('ui_spawn_prop'), desc: locale('ui_spawn_a_prop_object_using_its_hash'), icon: <Box size={20} />, example: 'p_chair01x' },
  { type: 'ped', label: locale('ui_spawn_ped'), desc: locale('ui_spawn_a_ped_npc_using_its_hash'), icon: <User size={20} />, example: 'a_m_m_valtownfolk_01' },
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
      toast.push({ type: 'success', title: locale('ui_spawn_requested') });
      setOpen(null);
      setHash('');
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_spawn'), description: res.message });
    }
  };

  const clearArea = async () => {
    const r = Math.min(100, Math.max(5, Number(radius) || 25));
    setClearing(true);
    const res = await fetchNui<{ success: boolean; message?: string }>('clearArea', { radius: r }, { success: true });
    setClearing(false);
    if (res.success) {
      toast.push({ type: 'success', title: locale('ui_clearing_entities_within_xm', r) });
      setShowClear(false);
    } else {
      toast.push({ type: 'error', title: locale('ui_failed_to_clear_area'), description: res.message });
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><Sparkles size={22} /> {locale('ui_entity_spawner')}</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">{locale('ui_spawn_vehicles_animals_props_and_peds_using')}</p>
      </div>

      <div className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 bg-[var(--rdr-accent-20)] text-[var(--rdr-accent-bright)]">
            <Trash2 size={20} />
          </div>
          <div>
            <p className="text-[var(--rdr-heading)] text-sm font-semibold">{locale('ui_clear_area')}</p>
            <p className="text-[var(--rdr-muted)] text-xs mt-0.5">{locale('ui_remove_spawned_peds_props_and_unridden_horse')}</p>
          </div>
        </div>
        <Button variant="outline" tone="red" fullWidth className="mt-3" onClick={() => setShowClear(true)}>
          <Trash2 size={14} /> {locale('ui_clear_area')}
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
              <Sparkles size={14} /> {locale('ui_spawn')}
            </Button>
          </div>
        ))}
      </div>

      <div className="rounded-lg p-4" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
        <p className="text-[var(--rdr-heading)] text-sm font-semibold flex items-center gap-2 mb-2"><Info size={15} /> {locale('ui_usage_tips')}</p>
        <ul className="text-[var(--rdr-muted)] text-xs space-y-1 list-disc list-inside">
          <li>{locale('ui_enter_the_exact_hash_name_of_the_entity_you')}</li>
          <li>{locale('ui_entities_will_spawn_near_your_current_positi')}</li>
          <li>{locale('ui_make_sure_the_hash_name_is_valid_for_redm')}</li>
          <li>{locale('ui_examples_cart01_a_c_deer_01_a_c_horse_arabia')}</li>
        </ul>
      </div>

      {open && (
        <Modal title={spawnCards.find((c) => c.type === open)?.label ?? locale('ui_spawn_entity')} subtitle={spawnCards.find((c) => c.type === open)?.desc} onClose={() => setOpen(null)} width="max-w-sm">
          <div className="space-y-3">
            <div>
              <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_hash_name')}</label>
              <input
                autoFocus
                value={hash}
                onChange={(e) => setHash(e.target.value)}
                placeholder={`e.g., ${spawnCards.find((c) => c.type === open)?.example}`}
                className="w-full mt-1 bg-[var(--rdr-surface)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]"
              />
              <p className="text-[var(--rdr-faint)] text-[11px] mt-1">{locale('ui_enter_the_exact_hash_name_of_the_entity')}</p>
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setOpen(null)}>{locale('ui_cancel')}</Button>
              <Button variant="solid" tone="accent" disabled={!hash.trim() || submitting} isLoading={submitting} onClick={submit}>
                <Sparkles size={14} /> {locale('ui_spawn')}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {showClear && (
        <Modal title={locale('ui_clear_area')} subtitle={locale('ui_remove_spawned_entities_around_you')} onClose={() => setShowClear(false)} width="max-w-sm">
          <div className="space-y-3">
            <div>
              <label className="text-xs text-[var(--rdr-muted)]">{locale('ui_radius_metres')}</label>
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
                {locale('ui_clears_npcs_animals_unridden_horses_and_spaw')}
              </p>
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setShowClear(false)}>{locale('ui_cancel')}</Button>
              <Button variant="solid" tone="red" disabled={clearing} isLoading={clearing} onClick={clearArea}>
                <Trash2 size={14} /> {locale('ui_clear_area')}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
