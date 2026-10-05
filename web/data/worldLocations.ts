import { locale } from '../i18n';
import type { TeleportCategory, TeleportLocation } from '../types';

// RDR2's world extents, used to plot world x/y onto the map panel — a square
// +/-16000 radius centered on 0,0, matching the de facto convention used by
// the open-source RedM community "webmap" tool (kibook/webmap), so a map
// image sized/cropped to that same convention lines up without extra tuning.
// If your image is calibrated differently, adjust these four numbers only.
export const WORLD_BOUNDS = { minX: -16000, maxX: 16000, minY: -16000, maxY: 16000 };

export function worldToPercent(x: number, y: number) {
  const px = ((x - WORLD_BOUNDS.minX) / (WORLD_BOUNDS.maxX - WORLD_BOUNDS.minX)) * 100;
  // map Y grows north; screen Y grows down, so invert
  const py = 100 - ((y - WORLD_BOUNDS.minY) / (WORLD_BOUNDS.maxY - WORLD_BOUNDS.minY)) * 100;
  return { left: Math.min(100, Math.max(0, px)), top: Math.min(100, Math.max(0, py)) };
}

export function percentToWorld(leftPct: number, topPct: number) {
  const x = WORLD_BOUNDS.minX + (leftPct / 100) * (WORLD_BOUNDS.maxX - WORLD_BOUNDS.minX);
  const y = WORLD_BOUNDS.minY + (1 - topPct / 100) * (WORLD_BOUNDS.maxY - WORLD_BOUNDS.minY);
  return { x, y };
}

export const categoryLabels: Record<TeleportCategory, string> = {
  towns: locale('ui_tpcat_towns'),
  gangcamps: locale('ui_tpcat_gangcamps'),
  nature: locale('ui_tpcat_nature'),
  shops: locale('ui_tpcat_shops'),
  special: locale('ui_tpcat_special'),
};

export const categoryIcons: Record<TeleportCategory, string> = {
  towns: '🏘️',
  gangcamps: '⛺',
  nature: '🏔️',
  shops: '🏪',
  special: '⭐',
};

// Curated starting set using real, well-known RDR2 world coordinates.
// Admins can expand this list at any time with "Add Location" / Custom Teleport.
export const builtInLocations: TeleportLocation[] = [
  // Towns & Cities
  { id: 'valentine', name: 'Valentine', category: 'towns', description: 'Livestock town in the Heartlands', x: -302.7, y: 799.8, z: 118.5, heading: 0, popular: true },
  { id: 'saintdenis', name: 'Saint Denis', category: 'towns', description: 'Major city and industrial center', x: 2638.9, y: -1180.5, z: 51.5, heading: 0, popular: true },
  { id: 'blackwater', name: 'Blackwater', category: 'towns', description: 'Modern town in Great Plains', x: -815.1, y: -1279.5, z: 44.4, heading: 0, popular: true },
  { id: 'strawberry', name: 'Strawberry', category: 'towns', description: 'Mountain town in Big Valley', x: -1749.8, y: -218.4, z: 158.2, heading: 0, popular: true },
  { id: 'rhodes', name: 'Rhodes', category: 'towns', description: 'Southern town in Lemoyne', x: 1332.9, y: -1305.3, z: 77.9, heading: 0, popular: true },
  { id: 'armadillo', name: 'Armadillo', category: 'towns', description: 'Desert town in New Austin', x: -3685.2, y: -2610.8, z: -13.4, heading: 0 },
  { id: 'tumbleweed', name: 'Tumbleweed', category: 'towns', description: 'Ghost town in New Austin', x: -5487.5, y: -2933.6, z: -1.4, heading: 0 },
  { id: 'annesburg', name: 'Annesburg', category: 'towns', description: 'Mining town in Roanoke Ridge', x: 2933.4, y: 1345.6, z: 44.1, heading: 0 },
  { id: 'vanhorn', name: 'Van Horn Trading Post', category: 'towns', description: 'Trading post on Lannahechee River', x: 2965.8, y: 566.9, z: 44.5, heading: 0 },

  // Nature & Landmarks
  { id: 'horseshoe', name: 'Horseshoe Overlook', category: 'nature', description: 'Chapter 1 camp overlook, Ambarino', x: 2884.6, y: 1291.0, z: 44.6, heading: 0, popular: true },
  { id: 'flatiron', name: 'Flat Iron Lake', category: 'nature', description: 'Large lake south of Rhodes', x: -20.0, y: -1550.0, z: 8.0, heading: 0 },
  { id: 'elysian', name: 'Elysian Pool', category: 'nature', description: 'Waterfall pool, Tall Trees', x: -2727.0, y: 1445.0, z: 293.0, heading: 0 },
  { id: 'sixpoint', name: 'Six Point Cabin', category: 'nature', description: 'Cabin in Ambarino', x: 1236.0, y: -145.0, z: 82.0, heading: 0 },
  { id: 'wapiti', name: 'Wapiti Indian Reservation', category: 'nature', description: 'Reservation in Big Valley', x: -2033.0, y: -1373.0, z: 45.0, heading: 0 },

  // Gang Camps
  { id: 'emeraldranch', name: 'Emerald Ranch', category: 'gangcamps', description: 'Chapter 3 camp, Lemoyne', x: 2136.5, y: -1281.9, z: 54.3, heading: 0, popular: true },
  { id: 'beaverhollow', name: 'Beaver Hollow', category: 'gangcamps', description: 'Chapter 5-6 camp, Tall Trees', x: -2159.0, y: 1211.0, z: 176.0, heading: 0 },
  { id: 'clemenspoint', name: "Clemens Point", category: 'gangcamps', description: 'Chapter 2 camp, Lemoyne', x: 1508.0, y: -1272.0, z: 76.0, heading: 0 },
  { id: 'shadybelle', name: 'Shady Belle', category: 'gangcamps', description: 'Chapter 4 camp, Lemoyne', x: 2467.0, y: -1198.0, z: 47.0, heading: 0 },

  // Shops & Services
  { id: 'keanessaloon', name: "Keane's Saloon", category: 'shops', description: 'Saloon in Valentine', x: -279.5, y: 810.0, z: 118.7, heading: 0, popular: true },
  { id: 'gunsmith_valentine', name: 'Valentine Gunsmith', category: 'shops', description: 'Gunsmith in Valentine', x: -228.0, y: 800.0, z: 118.7, heading: 0 },
  { id: 'fence_emerald', name: 'Fence (Emerald Station)', category: 'shops', description: 'Fence near Emerald Ranch', x: 2166.0, y: -1298.0, z: 48.0, heading: 0 },
  { id: 'butcher_valentine', name: 'Valentine Butcher', category: 'shops', description: 'Butcher in Valentine', x: -184.0, y: 785.0, z: 118.9, heading: 0 },

  // Special Locations
  { id: 'sheriff_valentine', name: 'Valentine Sheriff', category: 'special', description: "Sheriff's office in Valentine", x: -240.0, y: 838.0, z: 118.6, heading: 0 },
  { id: 'bank_saintdenis', name: 'Saint Denis Bank', category: 'special', description: 'Bank in Saint Denis', x: 2646.0, y: -1284.0, z: 53.3, heading: 0 },
  { id: 'traindepot_valentine', name: 'Valentine Station', category: 'special', description: 'Train station in Valentine', x: -260.0, y: 662.0, z: 116.8, heading: 0 },
];
