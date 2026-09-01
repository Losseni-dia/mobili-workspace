import { Component, OnInit, computed, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  AdminService,
  AdminStationOption,
  AdminTripStats,
  TripStatEntry,
  TripStatsDayEntry,
  TripStatsPeriod,
} from '../../../core/services/admin/admin.service';
import { Partner } from '../../../core/services/partners/partenaire.service';
import { ListPager } from '../../../core/utils/list-pager.util';
import { exportToCsv } from '../../../core/utils/csv-export.util';
import { toLocalDateString } from '../../../core/utils/period-range.util';

/**
 * Palette dataviz alignée sur l'identité Mobili (styles/_variables.scss) — un .ts ne peut pas
 * @use ces variables SCSS, valeurs dupliquées ici volontairement.
 */
const DONUT_COLORS = [
  '#092990', // $mobili-blue
  '#E6B800', // $mobili-yellow-dark
  '#0d9488', // $mobili-teal
  '#6b21a8', // $admin-purple
  '#15803d', // $station-green
  '#94a3b8', // $gray-400
];

/** Secteur SVG (un path par part — survol = translation radiale indépendante). */
interface DonutSegment {
  path: string;
  color: string;
  pullX: number;
  pullY: number;
}

const CX = 50;
const CY = 50;
const R_OUT = 45;
const R_IN = 28;
/** Déplacement radial (unités viewBox) quand on survole le secteur */
const PULL = 2.8;

export type GrowthMetric = 'revenue' | 'bookings';

/** Un point de la courbe de croissance, en coordonnées SVG (viewBox 0..GW x 0..GH). */
interface GrowthPoint {
  x: number;
  y: number;
  date: string;
  value: number;
}

const GW = 600;
const GH = 220;
const G_PAD_L = 8;
const G_PAD_R = 8;
const G_PAD_T = 12;
const G_PAD_B = 12;

@Component({
  selector: 'app-admin-business',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './admin-business.html',
  styleUrl: './admin-business.scss',
})
export class AdminBusiness implements OnInit {
  private adminService = inject(AdminService);

  period = signal<TripStatsPeriod>('WEEK');
  fromDate = signal('');
  toDate = signal('');
  /** Mode "Date précise" (une seule date, from=to) — pertinent seulement en période CUSTOM. */
  singleDateMode = signal(false);

  stationOptions = signal<AdminStationOption[]>([]);
  partnerOptions = signal<Partner[]>([]);
  stationFilter = signal<number | 'all'>('all');
  partnerFilter = signal<number | 'all'>('all');

  stats = signal<AdminTripStats | null>(null);
  isLoading = signal(false);
  loadError = signal(false);

  showMethodology = signal(false);
  search = signal('');

  /** Index de secteur survolé (null = rien) — CA puis volume. */
  hoveredRevenue = signal<number | null>(null);
  hoveredVolume = signal<number | null>(null);

  /** Métrique affichée sur la courbe de croissance — un seul axe, jamais les deux à la fois. */
  growthMetric = signal<GrowthMetric>('revenue');
  hoveredGrowth = signal<number | null>(null);

  filteredByBookings = computed(() => this.filterEntries(this.stats()?.top10ByBookings ?? []));
  filteredByRevenue = computed(() => this.filterEntries(this.stats()?.top10ByRevenue ?? []));

  pagerBookings = new ListPager(this.filteredByBookings);
  pagerRevenue = new ListPager(this.filteredByRevenue);

  revenueDonutSegments = computed((): DonutSegment[] => {
    const pcts = this.stats()?.revenueByTripDonut?.map((s) => s.percentOfTotal) ?? [];
    return buildDonutSegments(pcts, DONUT_COLORS);
  });

  volumeDonutSegments = computed((): DonutSegment[] => {
    const pcts = this.stats()?.volumeByTripDonut?.map((s) => s.percentOfTotal) ?? [];
    return buildDonutSegments(pcts, DONUT_COLORS);
  });

  /** Points de la courbe de croissance, mis à l'échelle du viewBox — un seul axe (Y). */
  growthPoints = computed((): GrowthPoint[] => {
    const timeline = this.stats()?.timeline ?? [];
    return buildGrowthPoints(timeline, this.growthMetric());
  });

  growthLinePath = computed(() => {
    const pts = this.growthPoints();
    return pts.length ? linePath(pts) : '';
  });

  growthAreaPath = computed(() => {
    const pts = this.growthPoints();
    return pts.length ? areaPath(pts) : '';
  });

  growthTicksY = computed(() => buildYTicks(this.growthPoints()));

  revenueSliceTransform(i: number, seg: DonutSegment): string {
    return this.hoveredRevenue() === i ? `translate(${seg.pullX} ${seg.pullY})` : 'translate(0 0)';
  }

  volumeSliceTransform(i: number, seg: DonutSegment): string {
    return this.hoveredVolume() === i ? `translate(${seg.pullX} ${seg.pullY})` : 'translate(0 0)';
  }

  periodLabel(): string {
    switch (this.period()) {
      case 'DAY':
        return 'Aujourd’hui (minuit → maintenant)';
      case 'WEEK':
        return '7 jours calendaires (aujourd’hui inclus : 6 jours avant + aujourd’hui)';
      case 'MONTH':
        return '30 jours calendaires (aujourd’hui inclus)';
      case 'YEAR':
        return '365 jours calendaires (aujourd’hui inclus)';
      case 'CUSTOM':
        return this.singleDateMode() ? 'Date précise choisie' : 'Intervalle personnalisé';
      default:
        return '';
    }
  }

  ngOnInit() {
    this.adminService.getStationOptions().subscribe({
      next: (opts) => this.stationOptions.set(opts || []),
      error: () => this.stationOptions.set([]),
    });
    this.adminService.getAllPartnersForAdmin().subscribe({
      next: (partners) => this.partnerOptions.set(partners || []),
      error: () => this.partnerOptions.set([]),
    });
    this.load();
  }

  setPeriod(p: TripStatsPeriod) {
    this.period.set(p);
    this.singleDateMode.set(false);
    this.load();
  }

  setCustomRange() {
    this.period.set('CUSTOM');
    this.singleDateMode.set(false);
    if (!this.fromDate() || !this.toDate()) {
      const now = new Date();
      const from = new Date(now);
      from.setDate(now.getDate() - 29);
      this.fromDate.set(toLocalDateString(from));
      this.toDate.set(toLocalDateString(now));
    }
    this.load();
  }

  setSingleDateMode() {
    this.period.set('CUSTOM');
    this.singleDateMode.set(true);
    const d = this.fromDate() || toLocalDateString(new Date());
    this.fromDate.set(d);
    this.toDate.set(d);
    this.load();
  }

  onFromDateChange(v: string) {
    this.fromDate.set(v);
    if (this.singleDateMode()) {
      this.toDate.set(v);
    }
    this.load();
  }

  onToDateChange(v: string) {
    this.toDate.set(v);
    this.load();
  }

  onStationFilterChange(raw: string) {
    this.stationFilter.set(raw === 'all' ? 'all' : Number(raw));
    this.load();
  }

  onPartnerFilterChange(raw: string) {
    this.partnerFilter.set(raw === 'all' ? 'all' : Number(raw));
    this.load();
  }

  onSearch(v: string) {
    this.search.set(v);
    this.pagerBookings.reset();
    this.pagerRevenue.reset();
  }

  toggleMethodology() {
    this.showMethodology.update((v) => !v);
  }

  setGrowthMetric(m: GrowthMetric) {
    this.growthMetric.set(m);
    this.hoveredGrowth.set(null);
  }

  onGrowthHover(evt: MouseEvent) {
    const pts = this.growthPoints();
    if (!pts.length) return;
    const svgEl = evt.currentTarget as SVGSVGElement;
    const rect = svgEl.getBoundingClientRect();
    const relX = ((evt.clientX - rect.left) / rect.width) * GW;
    let closest = 0;
    let bestDist = Infinity;
    for (let i = 0; i < pts.length; i++) {
      const d = Math.abs(pts[i].x - relX);
      if (d < bestDist) {
        bestDist = d;
        closest = i;
      }
    }
    this.hoveredGrowth.set(closest);
  }

  exportTopBookingsCsv() {
    exportToCsv(
      'top-trajets-volume',
      this.filteredByBookings().map((r) => ({
        rang: r.rank,
        route: r.route,
        partenaire: r.partnerName,
        gare: r.stationName,
        billets: r.bookingCount,
        ca_fcfa: r.revenueFcfa,
      })),
    );
  }

  exportTopRevenueCsv() {
    exportToCsv(
      'top-trajets-ca',
      this.filteredByRevenue().map((r) => ({
        rang: r.rank,
        route: r.route,
        partenaire: r.partnerName,
        gare: r.stationName,
        ca_fcfa: r.revenueFcfa,
        billets: r.bookingCount,
      })),
    );
  }

  private filterEntries(rows: TripStatEntry[]): TripStatEntry[] {
    const term = this.search().trim().toLowerCase();
    if (!term) return rows;
    return rows.filter(
      (r) =>
        r.route.toLowerCase().includes(term) ||
        r.partnerName.toLowerCase().includes(term) ||
        (r.stationName || '').toLowerCase().includes(term),
    );
  }

  private load() {
    this.isLoading.set(true);
    this.loadError.set(false);
    const station = this.stationFilter();
    const partner = this.partnerFilter();
    const opts = {
      fromDate: this.period() === 'CUSTOM' ? this.fromDate() || undefined : undefined,
      toDate: this.period() === 'CUSTOM' ? this.toDate() || undefined : undefined,
      stationId: station === 'all' ? null : station,
      partnerId: partner === 'all' ? null : partner,
    };
    this.adminService.getTripAnalytics(this.period(), opts).subscribe({
      next: (d) => {
        this.stats.set(d);
        this.isLoading.set(false);
        this.pagerBookings.reset();
        this.pagerRevenue.reset();
      },
      error: () => {
        this.loadError.set(true);
        this.stats.set(null);
        this.isLoading.set(false);
      },
    });
  }
}

function buildDonutSegments(percentages: number[], colors: string[]): DonutSegment[] {
  if (!percentages.length) {
    return [];
  }
  let acc = 0;
  const out: DonutSegment[] = [];
  for (let i = 0; i < percentages.length; i++) {
    const p = percentages[i] ?? 0;
    const start = acc;
    const add = Math.max(0, Math.min(100 - acc, p));
    acc = Math.min(100, acc + add);
    if (add <= 0) {
      continue;
    }
    const path = add >= 99.4 ? fullAnnulusPath(R_OUT, R_IN) : annularArcPath(start, acc, R_OUT, R_IN);
    const { pullX, pullY } =
      add >= 99.4
        ? { pullX: 0, pullY: -PULL }
        : (() => {
            const m = midAngleRads(start, acc);
            return { pullX: PULL * Math.cos(m), pullY: PULL * Math.sin(m) };
          })();
    out.push({
      path,
      color: colors[i % colors.length] ?? '#94a3b8',
      pullX,
      pullY,
    });
  }
  if (acc < 99.5) {
    const mid = midAngleRads(acc, 100);
    out.push({
      path: annularArcPath(acc, 100, R_OUT, R_IN),
      color: '#e2e8f0',
      pullX: PULL * Math.cos(mid),
      pullY: PULL * Math.sin(mid),
    });
  }
  return out;
}

function midAngleRads(startPct: number, endPct: number): number {
  const t0 = (-Math.PI / 2) + (2 * Math.PI * startPct) / 100;
  const t1 = (-Math.PI / 2) + (2 * Math.PI * endPct) / 100;
  return (t0 + t1) / 2;
}

/** Arc annulaire 12h → fin de tranche, angles en % (0–100). */
function annularArcPath(startPct: number, endPct: number, rOut: number, rIn: number): string {
  const t0 = (-Math.PI / 2) + (2 * Math.PI * startPct) / 100;
  const t1 = (-Math.PI / 2) + (2 * Math.PI * endPct) / 100;
  const dTheta = t1 - t0;
  const large = Math.abs(dTheta) > Math.PI ? 1 : 0;

  const x0o = CX + rOut * Math.cos(t0);
  const y0o = CY + rOut * Math.sin(t0);
  const x1o = CX + rOut * Math.cos(t1);
  const y1o = CY + rOut * Math.sin(t1);

  const x0i = CX + rIn * Math.cos(t0);
  const y0i = CY + rIn * Math.sin(t0);
  const x1i = CX + rIn * Math.cos(t1);
  const y1i = CY + rIn * Math.sin(t1);

  return [
    `M ${x0o} ${y0o}`,
    `A ${rOut} ${rOut} 0 ${large} 1 ${x1o} ${y1o}`,
    `L ${x1i} ${y1i}`,
    `A ${rIn} ${rIn} 0 ${large} 0 ${x0i} ${y0i}`,
    'Z',
  ].join(' ');
}

/** Anneau 360° (un seul segment ~100 %). */
function fullAnnulusPath(rOut: number, rIn: number): string {
  const t = 50;
  return [
    `M ${t} ${t - rOut}`,
    `A ${rOut} ${rOut} 0 1 1 ${t} ${t + rOut}`,
    `A ${rOut} ${rOut} 0 1 1 ${t} ${t - rOut - 0.01}`,
    `L ${t} ${t - rIn}`,
    `A ${rIn} ${rIn} 0 1 0 ${t} ${t + rIn}`,
    `A ${rIn} ${rIn} 0 1 0 ${t} ${t - rIn}`,
    'Z',
  ].join(' ');
}

/** Convertit la timeline brute en points SVG mis à l'échelle — un seul axe Y à la fois. */
function buildGrowthPoints(timeline: TripStatsDayEntry[], metric: GrowthMetric): GrowthPoint[] {
  if (!timeline.length) return [];
  const values = timeline.map((d) => (metric === 'revenue' ? d.revenueFcfa : d.bookingCount));
  const maxV = Math.max(...values, 1);
  const minV = 0; // toujours ancré à 0 — une courbe de volume/CA ne doit jamais paraître négative
  const innerW = GW - G_PAD_L - G_PAD_R;
  const innerH = GH - G_PAD_T - G_PAD_B;
  const n = timeline.length;
  return timeline.map((d, i) => {
    const v = metric === 'revenue' ? d.revenueFcfa : d.bookingCount;
    const x = n > 1 ? G_PAD_L + (innerW * i) / (n - 1) : G_PAD_L + innerW / 2;
    const t = maxV > minV ? (v - minV) / (maxV - minV) : 0;
    const y = G_PAD_T + innerH * (1 - t);
    return { x, y, date: d.date, value: v };
  });
}

function linePath(pts: GrowthPoint[]): string {
  return pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(2)} ${p.y.toFixed(2)}`).join(' ');
}

function areaPath(pts: GrowthPoint[]): string {
  const baseline = GH - G_PAD_B;
  const line = linePath(pts);
  const last = pts[pts.length - 1];
  const first = pts[0];
  return `${line} L ${last.x.toFixed(2)} ${baseline} L ${first.x.toFixed(2)} ${baseline} Z`;
}

/** 4 graduations Y recessives (0, 1/3, 2/3, max) — pas de sur-graduation sur une petite courbe. */
function buildYTicks(pts: GrowthPoint[]): number[] {
  if (!pts.length) return [];
  const innerH = GH - G_PAD_T - G_PAD_B;
  return [0, 0.33, 0.66, 1].map((f) => G_PAD_T + innerH * f);
}
