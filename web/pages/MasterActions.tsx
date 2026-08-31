import { ShieldAlert } from 'lucide-react';
import { MasterAdminPanel } from '../components/MasterAdminPanel';

export function MasterActions() {
  return (
    <div className="space-y-4 pb-6">
      <div>
        <h2 className="text-[var(--rdr-heading)] text-2xl font-bold flex items-center gap-2"><ShieldAlert size={22} /> Master Actions</h2>
        <p className="text-[var(--rdr-muted)] mt-1 text-sm">Owner only controls: Discord webhook routing and custom inventory items</p>
      </div>
      <MasterAdminPanel />
    </div>
  );
}
