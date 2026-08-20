import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

import legalContent from '../cgu-content.json';

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
 * Contenu externalisé dans cgu-content.json : c'est aussi la source lue par
 * scripts/generate-legal-static.mjs pour générer la version statique servie aux
 * robots/crawlers sans JS (voir public/cgu/index.html) — ne jamais dupliquer le texte
 * ailleurs, toujours modifier le JSON.
 */
@Component({
  selector: 'app-cgu',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './cgu.component.html',
  styleUrl: './cgu.component.scss',
})
export class CguComponent {
  readonly version = legalContent.version;
  readonly sections: LegalSection[] = legalContent.sections;
}
