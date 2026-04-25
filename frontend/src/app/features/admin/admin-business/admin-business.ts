import { Component, OnInit, computed, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AdminService, AdminTripStats, TripStatsPeriod } from '../../../core/services/admin/admin.service';

const DONUT_COLORS = ['#2563eb', '#7c3aed', '#db2777', '#ea580c', '#16a34a', '#64748b'];

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

@Component({
  selector: 'app-admin-business',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './admin-business.html',
  styleUrl: './admin-business.scss',
})
export class AdminBusiness implements OnInit {
  private adminService = inject(AdminService);

  period = signal<TripStatsPeriod>('WEEK');
  stats = signal<AdminTripStats | null>(null);
  loadError = signal(false);

  /** Index de secteur survolé (null = rien) — CA puis volume. */
  hoveredRevenue = signal<number | null>(null);
  hoveredVolume = signal<number | null>(null);

  revenueDonutSegments = computed((): DonutSegment[] => {
    const pcts = this.stats()?.revenueByTripDonut?.map((s) => s.percentOfTotal) ?? [];
    return buildDonutSegments(pcts, DONUT_COLORS);
  });

  volumeDonutSegments = computed((): DonutSegment[] => {
    const pcts = this.stats()?.volumeByTripDonut?.map((s) => s.percentOfTotal) ?? [];
    return buildDonutSegments(pcts, DONUT_COLORS);
  });

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
      default:
        return '';
    }
  }

  ngOnInit() {
    this.load();
  }

  setPeriod(p: TripStatsPeriod) {
    this.period.set(p);
    this.load();
  }

  private load() {
    this.loadError.set(false);
    this.adminService.getTripAnalytics(this.period()).subscribe({
      next: (d) => this.stats.set(d),
      error: () => {
        this.loadError.set(true);
        this.stats.set(null);
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
