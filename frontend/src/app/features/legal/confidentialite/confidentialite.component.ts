import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

import legalContent from '../confidentialite-content.json';

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
 * Contenu externalisé dans confidentialite-content.json : c'est aussi la source lue par
 * scripts/generate-legal-static.mjs pour générer la version statique servie aux
 * robots/crawlers sans JS (voir public/confidentialite/index.html) — ne jamais dupliquer le
 * texte ailleurs, toujours modifier le JSON.
 */
@Component({
  selector: 'app-confidentialite',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './confidentialite.component.html',
  styleUrl: './confidentialite.component.scss',
})
export class ConfidentialiteComponent {
  readonly version = legalContent.version;
  readonly intro = legalContent.intro;
  readonly sections: LegalSection[] = legalContent.sections;
}
