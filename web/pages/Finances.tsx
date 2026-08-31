import { useEffect, useMemo, useState } from 'react';
import { MessageCircle, Fingerprint } from 'lucide-react';
import { fetchNui, useNuiData } from '../hooks/useNui';
import { useToast } from '../components/Toast';
import { Dropdown } from '../components/Dropdown';
import { Button } from '../components/Button';
import { Avatar } from '../components/Avatar';
import type { FinanceData, ManagedPlayer, MoneyType, Permissions } from '../types';

const moneyTypes: { value: MoneyType; label: string }[] = [
  { value: 'bank', label: 'Std Bank' },
  { value: 'valbank', label: 'Val Bank' },
  { value: 'rhobank', label: 'Rho Bank' },
  { value: 'blkbank', label: 'Blk Bank' },
  { value: 'armbank', label: 'Arm Bank' },
  { value: 'cash', label: 'Cash' },
  { value: 'bloodmoney', label: 'Blood Money' },
];

const mockPlayers: ManagedPlayer[] = [
  { citizenid: 'DEV1234', serverId: 1, name: 'Dev Player', accountName: 'Steam Dev', job: 'Sheriff', money: 1450, playtimeMinutes: 320, lastSeen: new Date().toISOString(), online: true, discordName: 'uiforc', discordId: '458994322637848596', discordAvatarUrl: undefined, banned: false },
];

export function Finances({ permissions }: { permissions: Permissions | null }) {
  const toast = useToast();
  const canGiveMoney = permissions?.atLeastAdmin ?? false;
  const [playersData] = useNuiData<ManagedPlayer[]>('getAllPlayersManaged', {}, mockPlayers);
  const onlinePlayers = useMemo(() => (playersData ?? []).filter((p) => p.online && p.serverId != null), [playersData]);

  const [selectedId, setSelectedId] = useState<number | null>(null);
  const selected = onlinePlayers.find((p) => p.serverId === selectedId) ?? null;

  const [data, setData] = useState<FinanceData | null>(null);
  const [type, setType] = useState<MoneyType>('cash');
  const [amount, setAmount] = useState<number | ''>('');
  const numericAmount = Number(amount) || 0;

  const loadData = (id: number) => {
    fetchNui<FinanceData>('getFinanceData', { id }, {
      bank: 1200, valbank: 0, rhobank: 0, blkbank: 0, armbank: 0, cash: 250, bloodmoney: 0,
    }).then(setData);
  };

  useEffect(() => {
    if (selectedId != null) loadData(selectedId);
    else setData(null);
  }, [selectedId]);

  const submit = async (action: 'giveMoney' | 'removeMoney') => {
    if (selectedId == null || numericAmount <= 0) return;
    await fetchNui(action, { id: selectedId, type, amount: numericAmount }, { success: true });
    toast.push({ type: 'success', title: action === 'giveMoney' ? 'Money given' : 'Money removed' });
    loadData(selectedId);
  };

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold">Player Finances</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">Adjust an online player's money, select a player to begin</p>
      </div>

      <Dropdown
        value={selectedId != null ? String(selectedId) : ''}
        onChange={(v) => setSelectedId(v ? Number(v) : null)}
        placeholder="Select a player..."
        options={onlinePlayers.map((p) => ({
          value: String(p.serverId),
          label: `ID: ${p.serverId} | ${p.name}${p.discordName ? ` (@${p.discordName})` : ` (${p.accountName})`}`,
        }))}
      />
      {onlinePlayers.length === 0 && (
        <p className="text-[var(--rdr-faint)] text-xs">No players online.</p>
      )}

      {selected && data && (
        <>
          <div className="flex items-center gap-3 rounded-sm p-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <Avatar name={selected.name} size={44} imageUrl={selected.discordAvatarUrl} />
            <div className="min-w-0">
              <p className="text-[var(--rdr-heading)] text-base font-semibold truncate">{selected.name}</p>
              <p className="text-[var(--rdr-muted)] text-xs mt-0.5 flex items-center gap-1">
                {selected.discordName && <MessageCircle size={11} className="text-[#5865F2]" />}
                {selected.discordName ? `@${selected.discordName}` : selected.accountName}
              </p>
              <p className="text-[var(--rdr-faint)] text-[11px] mt-1 flex items-center gap-1">
                <Fingerprint size={11} /> Discord ID: {selected.discordId ?? 'Unavailable'} &middot; Citizen ID: {selected.citizenid}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-4 gap-3">
            {moneyTypes.map((m) => (
              <div key={m.value} className="rounded-sm p-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
                <p className="text-[var(--rdr-muted)] text-[11px] uppercase">{m.label}</p>
                <p className="text-[var(--rdr-accent-bright)] font-semibold mt-1">${data[m.value]}</p>
              </div>
            ))}
          </div>

          <div className="rounded-sm p-4 space-y-3" style={{ background: 'var(--rdr-surface)', border: '1px solid var(--rdr-border)' }}>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-[var(--rdr-muted)]">Account Type</label>
                <div className="mt-1">
                  <Dropdown value={type} onChange={setType} options={moneyTypes} />
                </div>
              </div>
              <div>
                <label className="text-xs text-[var(--rdr-muted)]">Amount</label>
                <input type="number" min={0} value={amount} onChange={(e) => setAmount(e.target.value === '' ? '' : Number(e.target.value))} className="w-full mt-1 bg-[var(--rdr-bg-elev)] border border-[var(--rdr-border)] rounded-sm px-3 py-2 text-sm text-[var(--rdr-text)]" />
              </div>
            </div>
            {canGiveMoney ? (
              <div className="flex gap-2">
                <Button variant="outline" tone="green" fullWidth onClick={() => submit('giveMoney')}>Give Money</Button>
                <Button variant="outline" tone="red" fullWidth onClick={() => submit('removeMoney')}>Remove Money</Button>
              </div>
            ) : (
              <p className="text-[var(--rdr-faint)] text-xs">Your role does not have permission to adjust player money.</p>
            )}
          </div>
        </>
      )}
    </div>
  );
}
