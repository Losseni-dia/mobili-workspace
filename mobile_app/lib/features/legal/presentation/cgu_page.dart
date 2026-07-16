import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CguPage extends StatelessWidget {
  const CguPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: const MobiliAppBar(
        title: "Conditions Générales d'Utilisation",
        showBackButton: true,
        titleFontSize: 15,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.mobiliBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gavel_rounded,
                      color: AppColors.mobiliYellow, size: 32),
                  const SizedBox(height: 12),
                  Text("Conditions Générales d'Utilisation",
                      style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text("Version 1.0 — Entrée en vigueur : Juillet 2026",
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const _Section(
              number: "1",
              title: "Présentation de Mobili",
              content:
                  """Mobili est une plateforme numérique de billetterie et de réservation de transport développée par la société Mobili SAS, dont le siège social est établi en Côte d'Ivoire.

La plateforme Mobili a vocation à connecter les voyageurs avec les compagnies de transport et les conducteurs de covoiturage opérant en Afrique subsaharienne, notamment en Côte d'Ivoire et dans la zone UEMOA.

La plateforme est accessible via :
• L'application mobile Mobili (Android)
• Le site web www.my-mobili.com

En utilisant Mobili, vous acceptez sans réserve les présentes Conditions Générales d'Utilisation (CGU).""",
            ),

            const _Section(
              number: "2",
              title: "Définitions",
              content:
                  """Dans les présentes CGU, les termes suivants ont les définitions ci-après :

• "Mobili" ou "la Plateforme" : l'ensemble des services numériques proposés par Mobili SAS.
• "Utilisateur" ou "Passager" : toute personne physique utilisant la plateforme pour rechercher, réserver ou acheter des billets de transport.
• "Partenaire" : toute société de transport ou compagnie de bus ayant conclu un accord avec Mobili pour distribuer ses billets via la plateforme.
• "Conducteur" : toute personne proposant des trajets de covoiturage via la plateforme après validation de son dossier.
• "Billet" : le titre de transport électronique généré à l'issue d'une réservation confirmée et payée.
• "Trajet" : tout déplacement proposé par un Partenaire ou un Conducteur sur la plateforme.""",
            ),

            const _Section(
              number: "3",
              title: "Création de compte et conditions d'accès",
              content: """3.1 Conditions d'éligibilité
Pour créer un compte Mobili, vous devez :
• Être une personne physique âgée d'au moins 18 ans ou être accompagné d'un représentant légal.
• Disposer d'un numéro de téléphone valide en Afrique subsaharienne ou ailleurs.
• Fournir des informations exactes, complètes et à jour lors de l'inscription.

3.2 Responsabilité du compte
Vous êtes seul(e) responsable de la confidentialité de votre identifiant et de votre mot de passe. Toute action effectuée depuis votre compte est réputée avoir été effectuée par vous. En cas de perte ou de vol de vos identifiants, vous devez immédiatement contacter le support Mobili.

3.3 Unicité du compte
Chaque utilisateur ne peut disposer que d'un seul compte actif sur la plateforme. La création de comptes multiples est strictement interdite et peut entraîner la suspension de l'ensemble des comptes concernés.

3.4 Suspension et résiliation
Mobili se réserve le droit de suspendre ou de supprimer tout compte en cas de violation des présentes CGU, de comportement frauduleux, ou de mise en danger des autres utilisateurs ou partenaires.""",
            ),

            const _Section(
              number: "4",
              title: "Services proposés",
              content: """4.1 Réservation de billets
Mobili permet aux utilisateurs de consulter les trajets disponibles proposés par les compagnies partenaires, de sélectionner leurs sièges, et de procéder au paiement en ligne via mobile money (Orange Money, MTN Mobile Money, Wave, Moov, etc.) ou par carte bancaire.

4.2 Covoiturage
Mobili propose également un service de covoiturage permettant à des particuliers vérifiés (conducteurs validés KYC) de proposer des trajets entre particuliers. Ce service est soumis à une vérification préalable du conducteur (pièce d'identité, photo, immatriculation du véhicule).

4.3 Billet électronique
À l'issue de chaque réservation payée, un billet électronique comportant un code QR unique est généré. Ce billet est nominatif et doit être présenté au moment de l'embarquement.

4.4 Disponibilité
Mobili s'efforce de maintenir la plateforme accessible 24h/24 et 7j/7, mais ne peut garantir une disponibilité continue. Des interruptions pour maintenance peuvent survenir sans préavis.""",
            ),

            const _Section(
              number: "5",
              title: "Tarifs, paiement et remboursements",
              content: """5.1 Prix
Les prix des billets sont affichés en Francs CFA (FCFA) ou en toute devise applicable selon le pays de l'utilisateur. Les prix sont ceux en vigueur au moment de la réservation et peuvent varier selon la disponibilité et la demande.

5.2 Paiement
Le paiement est effectué au moment de la réservation, via les solutions de paiement mobile intégrées à la plateforme (FedaPay, Orange Money, MTN MoMo, Wave, etc.). Mobili ne conserve aucune donnée de carte bancaire.

5.3 Confirmation
La réservation n'est confirmée qu'après validation du paiement. En cas d'échec du paiement, aucune réservation n'est créée.

5.4 Annulation et remboursement
Les conditions d'annulation et de remboursement dépendent de la politique de chaque compagnie partenaire. Pour les trajets covoiturage, des conditions spécifiques s'appliquent. Mobili facilite les demandes de remboursement mais ne peut être tenu responsable des décisions prises par les compagnies partenaires.

5.5 Commission
Mobili perçoit une commission sur chaque transaction effectuée via la plateforme. Cette commission est incluse dans le prix affiché à l'utilisateur.""",
            ),

            const _Section(
              number: "6",
              title: "Obligations des utilisateurs",
              content:
                  """En utilisant la plateforme Mobili, vous vous engagez à :

• Fournir des informations exactes et sincères lors de l'inscription et lors de toute réservation.
• Ne pas utiliser la plateforme à des fins illicites, frauduleuses ou contraires à l'ordre public.
• Ne pas tenter de pirater, de perturber ou de dégrader le fonctionnement de la plateforme.
• Ne pas revendre, transférer ou céder des billets sans autorisation préalable.
• Respecter les règles de conduite vis-à-vis des autres utilisateurs, conducteurs et personnel des compagnies partenaires.
• Ne pas créer de faux avis ou de fausses évaluations.
• Vous présenter à l'heure indiquée sur votre billet pour l'embarquement.""",
            ),

            const _Section(
              number: "7",
              title: "Responsabilité de Mobili",
              content: """7.1 Rôle d'intermédiaire
Mobili agit en qualité d'intermédiaire entre les utilisateurs et les compagnies de transport ou conducteurs partenaires. Mobili n'est pas transporteur et n'est pas responsable des incidents survenus lors du transport (retards, annulations, accidents, pertes de bagages).

7.2 Limitation de responsabilité
Mobili ne peut être tenu responsable :
• Des retards, annulations ou modifications de trajets décidés par les compagnies partenaires.
• Des dommages directs ou indirects résultant de l'utilisation de la plateforme.
• Des pannes temporaires de la plateforme ou de services tiers (opérateurs mobile money, etc.).
• Des actes frauduleux commis par des tiers utilisant la plateforme.

7.3 Force majeure
Mobili est dégagé de toute responsabilité en cas d'événement de force majeure (catastrophes naturelles, conflits, pandémies, décisions gouvernementales, etc.).""",
            ),

            const _Section(
              number: "8",
              title: "Propriété intellectuelle",
              content:
                  """L'ensemble des éléments constituant la plateforme Mobili (logo, charte graphique, textes, fonctionnalités, code source, etc.) sont la propriété exclusive de Mobili SAS et sont protégés par le droit de la propriété intellectuelle applicable.

Toute reproduction, représentation, modification, publication ou exploitation de ces éléments, sans autorisation écrite préalable de Mobili, est strictement interdite et constitue une contrefaçon sanctionnée par la loi.""",
            ),

            const _Section(
              number: "9",
              title: "Modification des CGU",
              content:
                  """Mobili se réserve le droit de modifier les présentes CGU à tout moment. Les utilisateurs seront informés de toute modification significative via une notification dans l'application ou par email si renseigné.

La poursuite de l'utilisation de la plateforme après notification des modifications vaut acceptation des nouvelles CGU. Si vous n'acceptez pas les modifications, vous avez la possibilité de supprimer votre compte.""",
            ),

            const _Section(
              number: "10",
              title: "Loi applicable et juridiction",
              content:
                  """Les présentes CGU sont régies par le droit ivoirien et, le cas échéant, par le droit UEMOA applicable.

Tout litige relatif à l'interprétation ou à l'exécution des présentes CGU sera soumis, à défaut de résolution amiable, aux tribunaux compétents d'Abidjan, Côte d'Ivoire.

Pour les utilisateurs résidant hors de Côte d'Ivoire, Mobili s'engage à rechercher une solution amiable avant tout recours judiciaire.""",
            ),

            const _Section(
              number: "11",
              title: "Contact et support",
              content:
                  """Pour toute question relative aux présentes CGU ou à l'utilisation de la plateforme, vous pouvez contacter notre équipe :

• Via le support intégré dans l'application Mobili
• Par email : support@my-mobili.com
• Via notre site web : www.my-mobili.com

Notre équipe s'engage à répondre à toute demande dans un délai maximum de 72 heures ouvrées.""",
            ),

            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mobiliBlueFog,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.mobiliBlue.withValues(alpha: 0.2)),
              ),
              child: Text(
                "Ces CGU ont été rédigées en français et sont applicables à compter du 1er juillet 2026. Elles remplacent toute version antérieure.",
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.mobiliBlue,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.number, required this.title, required this.content});
  final String number, title, content;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: AppColors.mobiliBlue.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: const Border(bottom: BorderSide(color: AppColors.gray100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.mobiliBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(number,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.mobiliBlueDeep,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(content,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.gray700, height: 1.6)),
          ),
        ],
      ),
    );
  }
}
