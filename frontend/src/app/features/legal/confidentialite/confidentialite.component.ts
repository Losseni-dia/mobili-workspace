import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

import legalContent from '../confidentialite-content.json';
import { SeoService } from '../../../core/services/seo/seo.service';

interface LegalSection {
  number: string;
  title: string;
  content: string;
}

/**
 * Politique de confidentialité — texte repris tel quel de l'app mobile
 * (mobile_app/lib/features/legal/presentation/confidentialite_page.dart), même arbitrage que
 * pour les CGU : un seul texte juridique cohérent entre mobile et web.
 *
 * Contenu externalisé dans confidentialite-content.json — ne jamais dupliquer le texte ailleurs,
 * toujours modifier le JSON. Cette route est en RenderMode.Prerender (voir app.routes.server.ts) :
 * les crawlers/robots reçoivent directement le HTML complet généré par ce composant au build,
 * plus besoin d'une version statique dupliquée à la main (ancien
 * scripts/generate-legal-static.mjs, retiré une fois le SSR en place).
 */
@Component({
  selector: 'app-confidentialite',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './confidentialite.component.html',
  styleUrl: './confidentialite.component.scss',
})
export class ConfidentialiteComponent implements OnInit {
  private readonly seo = inject(SeoService);

  readonly version = legalContent.version;
  readonly intro = legalContent.intro;
  readonly sections: LegalSection[] = legalContent.sections;

  ngOnInit(): void {
    this.seo.setPageSeo({
      title: 'Politique de confidentialité — Mobili',
      description:
        'Politique de confidentialité de Mobili : comment vos données sont collectées et utilisées lors de vos réservations de trajets.',
      canonicalPath: '/confidentialite',
    });
    this.seo.setStructuredData({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: 'Politique de confidentialité — Mobili',
      url: 'https://www.my-mobili.com/confidentialite',
      isPartOf: { '@type': 'WebSite', name: 'Mobili', url: 'https://www.my-mobili.com' },
    });
  }
}
