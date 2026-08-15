import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

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
 */
@Component({
  selector: 'app-cgu',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './cgu.component.html',
  styleUrl: './cgu.component.scss',
})
export class CguComponent {
  readonly version = 'Version 1.0 — Entrée en vigueur : Juillet 2026';

  readonly sections: LegalSection[] = [
    {
      number: '1',
      title: 'Présentation de Mobili',
      content: `Mobili est une plateforme numérique de billetterie et de réservation de transport développée par la société Mobili SAS, dont le siège social est établi en Côte d'Ivoire.

La plateforme Mobili a vocation à connecter les voyageurs avec les compagnies de transport et les conducteurs de covoiturage opérant en Afrique subsaharienne, notamment en Côte d'Ivoire et dans la zone UEMOA.

La plateforme est accessible via :
• L'application mobile Mobili (Android)
• Le site web www.my-mobili.com

En utilisant Mobili, vous acceptez sans réserve les présentes Conditions Générales d'Utilisation (CGU).`,
    },
    {
      number: '5',
      title: 'Tarifs, paiement et remboursements',
      content: `5.1 Prix
Les prix des billets sont affichés en Francs CFA (FCFA) ou en toute devise applicable selon le pays de l'utilisateur. Les prix sont ceux en vigueur au moment de la réservation et peuvent varier selon la disponibilité et la demande.

5.2 Paiement
Le paiement est effectué au moment de la réservation, via les solutions de paiement mobile intégrées à la plateforme (FedaPay, Orange Money, MTN MoMo, Wave, etc.). Mobili ne conserve aucune donnée de carte bancaire.

5.3 Confirmation
La réservation n'est confirmée qu'après validation du paiement. En cas d'échec du paiement, aucune réservation n'est créée.
5.4 Annulation et remboursement

a) Annulation à l'initiative du Passager
Le Passager peut annuler sa réservation depuis la section « Mes réservations » de l'application, tant que le trajet n'a pas eu lieu. Le montant remboursé dépend du délai entre l'annulation et l'heure de départ prévue :
- Plus de 24 heures avant le départ : remboursement de 90% du prix du transport.
- Entre 6 heures et 24 heures avant le départ : remboursement de 50% du prix du transport.
- Moins de 6 heures avant le départ, ou après le départ : aucun remboursement.
Les frais de service (frais de réservation forfaitaires appliqués lors de l'achat) ne sont remboursables dans aucun cas, sauf annulation à l'initiative de la compagnie (voir point b). En cas de bagages supplémentaires payants, ceux-ci suivent le même taux de remboursement que le prix du transport.

b) Annulation à l'initiative de la compagnie partenaire
Si un trajet est annulé, supprimé ou rendu impossible par la compagnie de transport (panne, surbooking, annulation de service), le Passager est remboursé intégralement, y compris les frais de service, sous un délai de 5 jours ouvrés. Une solution de report gratuit vers un trajet équivalent peut également être proposée en alternative au remboursement.

c) Non-présentation du Passager
Le Passager doit se présenter au point d'embarquement au moins 30 minutes avant l'heure de départ prévue. Passé un délai de grâce de 10 minutes après l'heure de départ, le Passager est considéré absent (« no-show ») et sa réservation est annulée sans droit à remboursement.

d) Covoiturage
Pour les trajets de covoiturage, l'annulation est gratuite tant que le Conducteur n'a pas accepté la demande, ou entre l'acceptation et la confirmation du paiement. Une fois le paiement confirmé, le barème de remboursement décrit au point (a) s'applique, avec des seuils pouvant être ajustés pour tenir compte du caractère non-professionnel du service. Si le Conducteur annule après avoir accepté une réservation payée, le Passager est remboursé intégralement et immédiatement.

e) Utilisation abusive
Mobili se réserve le droit de restreindre temporairement l'accès aux fonctionnalités de réservation d'un compte ayant procédé à des annulations répétées et abusives (au-delà de 3 annulations sur une même semaine), afin de protéger la disponibilité des sièges pour l'ensemble des utilisateurs.

f) Modalités de remboursement
Tout remboursement est effectué sur le moyen de paiement d'origine (mobile money ou carte bancaire), dans un délai indicatif de 3 à 5 jours ouvrés, sous réserve des délais propres à chaque opérateur de paiement.

5.5 Commission
Mobili perçoit une commission sur chaque transaction effectuée via la plateforme. Cette commission est incluse dans le prix affiché à l'utilisateur.`,
    },
    {
      number: '6',
      title: 'Obligations des utilisateurs',
      content: `En utilisant la plateforme Mobili, vous vous engagez à :

• Fournir des informations exactes et sincères lors de l'inscription et lors de toute réservation.
• Ne pas utiliser la plateforme à des fins illicites, frauduleuses ou contraires à l'ordre public.
• Ne pas tenter de pirater, de perturber ou de dégrader le fonctionnement de la plateforme.
• Ne pas revendre, transférer ou céder des billets sans autorisation préalable.
• Respecter les règles de conduite vis-à-vis des autres utilisateurs, conducteurs et personnel des compagnies partenaires.
• Ne pas créer de faux avis ou de fausses évaluations.
• Vous présenter à l'heure indiquée sur votre billet pour l'embarquement.`,
    },
    {
      number: '7',
      title: 'Responsabilité de Mobili',
      content: `7.1 Rôle d'intermédiaire
Mobili agit en qualité d'intermédiaire entre les utilisateurs et les compagnies de transport ou conducteurs partenaires. Mobili n'est pas transporteur et n'est pas responsable des incidents survenus lors du transport (retards, annulations, accidents, pertes de bagages).

7.2 Limitation de responsabilité
Mobili ne peut être tenu responsable :
• Des retards, annulations ou modifications de trajets décidés par les compagnies partenaires.
• Des dommages directs ou indirects résultant de l'utilisation de la plateforme.
• Des pannes temporaires de la plateforme ou de services tiers (opérateurs mobile money, etc.).
• Des actes frauduleux commis par des tiers utilisant la plateforme.

7.3 Force majeure
Mobili est dégagé de toute responsabilité en cas d'événement de force majeure (catastrophes naturelles, conflits, pandémies, décisions gouvernementales, etc.).`,
    },
    {
      number: '8',
      title: 'Propriété intellectuelle',
      content: `L'ensemble des éléments constituant la plateforme Mobili (logo, charte graphique, textes, fonctionnalités, code source, etc.) sont la propriété exclusive de Mobili SAS et sont protégés par le droit de la propriété intellectuelle applicable.

Toute reproduction, représentation, modification, publication ou exploitation de ces éléments, sans autorisation écrite préalable de Mobili, est strictement interdite et constitue une contrefaçon sanctionnée par la loi.`,
    },
    {
      number: '9',
      title: 'Modification des CGU',
      content: `Mobili se réserve le droit de modifier les présentes CGU à tout moment. Les utilisateurs seront informés de toute modification significative via une notification dans l'application ou par email si renseigné.

La poursuite de l'utilisation de la plateforme après notification des modifications vaut acceptation des nouvelles CGU. Si vous n'acceptez pas les modifications, vous avez la possibilité de supprimer votre compte.`,
    },
    {
      number: '10',
      title: 'Loi applicable et juridiction',
      content: `Les présentes CGU sont régies par le droit ivoirien et, le cas échéant, par le droit UEMOA applicable.

Tout litige relatif à l'interprétation ou à l'exécution des présentes CGU sera soumis, à défaut de résolution amiable, aux tribunaux compétents d'Abidjan, Côte d'Ivoire.

Pour les utilisateurs résidant hors de Côte d'Ivoire, Mobili s'engage à rechercher une solution amiable avant tout recours judiciaire.`,
    },
    {
      number: '11',
      title: 'Contact et support',
      content: `Pour toute question relative aux présentes CGU ou à l'utilisation de la plateforme, vous pouvez contacter notre équipe :

• Via le support intégré dans l'application Mobili
• Par email : support@my-mobili.com
• Via notre site web : www.my-mobili.com

Notre équipe s'engage à répondre à toute demande dans un délai maximum de 72 heures ouvrées.`,
    },
  ];
}
