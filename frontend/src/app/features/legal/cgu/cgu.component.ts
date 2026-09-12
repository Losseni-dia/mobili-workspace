import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

import legalContent from '../cgu-content.json';
import { SeoService } from '../../../core/services/seo/seo.service';

interface LegalSection {
  number: string;
  title: string;
  content: string;
}

/**
 * Conditions Générales d'Utilisation — texte repris tel quel de l'app mobile
 * (mobile_app/lib/features/legal/presentation/cgu_page.dart) pour garantir un seul texte
 * juridique cohérent entre les deux plateformes. Ne pas modifier le contenu sans repasser par le
 * même arbitrage que côté mobile.
 *
 * Contenu externalisé dans cgu-content.json — ne jamais dupliquer le texte ailleurs, toujours
 * modifier le JSON. Cette route est en RenderMode.Prerender (voir app.routes.server.ts) : les
 * crawlers/robots reçoivent directement le HTML complet généré par ce composant au build, plus
 * besoin d'une version statique dupliquée à la main (ancien scripts/generate-legal-static.mjs,
 * retiré une fois le SSR en place).
 */
@Component({
  selector: 'app-cgu',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './cgu.component.html',
  styleUrl: './cgu.component.scss',
})
export class CguComponent implements OnInit {
  private readonly seo = inject(SeoService);

  readonly version = legalContent.version;
  readonly sections: LegalSection[] = legalContent.sections;

  ngOnInit(): void {
    this.seo.setPageSeo({
      title: "Conditions générales d'utilisation — Mobili",
      description:
        "Conditions générales d'utilisation de Mobili : réservation de trajets bus, car et covoiturage en Afrique de l'Ouest.",
      canonicalPath: '/cgu',
    });
    this.seo.setStructuredData({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: "Conditions générales d'utilisation — Mobili",
      url: 'https://www.my-mobili.com/cgu',
      isPartOf: { '@type': 'WebSite', name: 'Mobili', url: 'https://www.my-mobili.com' },
    });
  }
}
