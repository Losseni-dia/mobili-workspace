import 'package:flutter/material.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ConfidentialitePage extends StatelessWidget {
  const ConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: const MobiliAppBar(
        title: "Politique de Confidentialité",
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
                  const Icon(Icons.shield_rounded,
                      color: AppColors.mobiliYellow, size: 32),
                  const SizedBox(height: 12),
                  Text("Politique de Confidentialité & Protection des Données",
                      style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text("Version 1.0 — Entrée en vigueur : Juillet 2026",
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Note intro
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.mobiliBlueFog,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.mobiliBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.mobiliBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Chez Mobili, la protection de vos données personnelles est une priorité. Cette politique explique quelles données nous collectons, pourquoi, et comment nous les protégeons.",
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.mobiliBlue, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const _Section(
              number: "1",
              title: "Responsable du traitement",
              content:
                  """Le responsable du traitement de vos données personnelles est :

Mobili SAS
Siège social : Abidjan, Côte d'Ivoire
Email : privacy@my-mobili.com
Site web : www.my-mobili.com

Mobili SAS s'engage à traiter vos données personnelles dans le respect de la législation applicable en matière de protection des données, notamment :
• Le Règlement Général sur la Protection des Données (RGPD) de l'Union Européenne
• La loi ivoirienne n°2013-450 du 19 juin 2013 relative à la protection des données à caractère personnel
• Les réglementations équivalentes des pays d'Afrique subsaharienne où Mobili opère""",
            ),

            const _Section(
              number: "2",
              title: "Données collectées",
              content: """2.1 Données que vous nous fournissez directement
• Informations d'identité : prénom, nom de famille
• Coordonnées : numéro de téléphone, adresse email (facultative)
• Identifiants de connexion : nom d'utilisateur, mot de passe (chiffré)
• Photo de profil (facultative)
• Informations de paiement : numéro de mobile money (traité par FedaPay, non stocké par Mobili)

2.2 Données collectées automatiquement
• Données d'utilisation : historique des recherches, réservations effectuées, billets achetés
• Données techniques : type d'appareil, système d'exploitation, version de l'application
• Token de notification push (Firebase FCM) pour l'envoi de notifications
• Données analytiques anonymisées via Firebase Analytics

2.3 Données collectées pour le covoiturage (conducteurs uniquement)
• Pièce d'identité (recto/verso) — stockée de façon sécurisée
• Photo du conducteur
• Photo et immatriculation du véhicule
• Numéro de la carte grise
• Date de validité de la pièce d'identité""",
            ),

            const _Section(
              number: "3",
              title: "Finalités du traitement",
              content:
                  """Vos données personnelles sont utilisées pour les finalités suivantes :

3.1 Exécution du contrat (base légale : contrat)
• Création et gestion de votre compte utilisateur
• Traitement de vos réservations et paiements
• Génération et envoi de vos billets électroniques
• Service client et gestion des demandes de remboursement

3.2 Obligations légales (base légale : obligation légale)
• Vérification d'identité des conducteurs covoiturage (KYC)
• Archivage des transactions conformément aux obligations fiscales
• Réponse aux réquisitions judiciaires ou administratives légalement fondées

3.3 Intérêt légitime (base légale : intérêt légitime)
• Amélioration de nos services et de l'expérience utilisateur
• Prévention de la fraude et sécurisation de la plateforme
• Analyse statistique anonymisée de l'utilisation de la plateforme
• Envoi de notifications liées à vos réservations

3.4 Consentement (base légale : consentement)
• Envoi de communications marketing et promotionnelles (avec votre accord explicite)
• Personnalisation des trajets suggérés""",
            ),

            const _Section(
              number: "4",
              title: "Conservation des données",
              content:
                  """Vos données personnelles sont conservées pour les durées suivantes :

• Données de compte : pendant toute la durée de votre inscription + 3 ans après suppression du compte
• Historique des réservations et billets : 5 ans (obligations comptables et fiscales)
• Documents KYC (conducteurs) : 5 ans après la fin de la relation contractuelle
• Données de connexion et logs : 1 an
• Données analytiques anonymisées : illimitée (car non personnelles)
• Tokens de notification push : jusqu'à désinstallation de l'application ou révocation

À l'expiration de ces délais, vos données sont supprimées ou anonymisées de façon irréversible.""",
            ),

            const _Section(
              number: "5",
              title: "Partage des données",
              content: """5.1 Partenaires de transport
Pour permettre la réalisation de votre trajet, certaines de vos données (nom, numéro de téléphone, numéro de siège) sont transmises à la compagnie de transport concernée.

5.2 Prestataires de services
Nous faisons appel à des prestataires de confiance pour assurer nos services :
• FedaPay : traitement sécurisé des paiements mobile money
• Firebase (Google) : notifications push et analytiques
• Amazon Web Services (AWS) : hébergement sécurisé de la plateforme

Ces prestataires sont contractuellement tenus de protéger vos données et de ne pas les utiliser à d'autres fins.

5.3 Autorités compétentes
Mobili peut être amené à communiquer vos données aux autorités judiciaires, policières ou administratives sur réquisition légalement fondée.

5.4 Ce que nous ne faisons jamais
• Nous ne vendons jamais vos données personnelles à des tiers.
• Nous ne partageons pas vos données à des fins publicitaires tierces.
• Nous ne communiquons jamais votre mot de passe (il est chiffré et inaccessible même pour nous).""",
            ),

            const _Section(
              number: "6",
              title: "Vos droits",
              content:
                  """Conformément à la réglementation applicable, vous disposez des droits suivants sur vos données personnelles :

• Droit d'accès : obtenir une copie de vos données personnelles que nous détenons.
• Droit de rectification : corriger des données inexactes ou incomplètes.
• Droit à l'effacement ("droit à l'oubli") : demander la suppression de vos données, sous réserve de nos obligations légales de conservation.
• Droit à la limitation : demander la restriction du traitement de vos données.
• Droit à la portabilité : recevoir vos données dans un format structuré et lisible par machine.
• Droit d'opposition : vous opposer à certains traitements, notamment à des fins de prospection commerciale.
• Droit de retirer votre consentement : à tout moment, sans affecter la licéité du traitement effectué avant le retrait.

Pour exercer vos droits, contactez-nous à : privacy@my-mobili.com

Nous nous engageons à répondre à toute demande dans un délai de 30 jours. En cas de réponse insatisfaisante, vous pouvez saisir l'autorité de protection des données compétente dans votre pays.""",
            ),

            const _Section(
              number: "7",
              title: "Sécurité des données",
              content:
                  """Mobili met en œuvre des mesures techniques et organisationnelles appropriées pour protéger vos données contre tout accès non autorisé, perte, destruction ou divulgation :

• Chiffrement des mots de passe (bcrypt)
• Connexions sécurisées HTTPS/TLS sur toutes les communications
• Hébergement sur AWS avec chiffrement des données au repos
• Accès aux données restreint au personnel autorisé uniquement
• Sauvegardes régulières et sécurisées
• Journalisation des accès et des modifications
• Documents KYC stockés dans des répertoires sécurisés et non accessibles publiquement
• Pas de stockage des données de paiement (déléguées à FedaPay)

En cas de violation de données susceptible d'affecter vos droits, nous nous engageons à vous en informer dans les meilleurs délais conformément à la réglementation applicable.""",
            ),

            const _Section(
              number: "8",
              title: "Cookies et technologies similaires",
              content:
                  """L'application mobile Mobili utilise les technologies suivantes :

• Firebase Analytics : analyse anonymisée de l'utilisation de l'application (écrans consultés, durée de session). Ces données sont agrégées et ne permettent pas de vous identifier personnellement.
• Firebase Cloud Messaging (FCM) : envoi de notifications push liées à vos réservations et alertes importantes. Vous pouvez désactiver ces notifications dans les paramètres de votre téléphone.
• Stockage local : l'application peut stocker localement certaines données (session de connexion, préférences) pour améliorer votre expérience. Ces données ne sont pas partagées.

Aucun cookie publicitaire ou de suivi tiers n'est utilisé dans l'application mobile Mobili.""",
            ),

            const _Section(
              number: "9",
              title: "Transferts internationaux de données",
              content:
                  """Dans le cadre de nos activités, certaines de vos données peuvent être transférées vers des serveurs situés hors de votre pays de résidence, notamment :

• AWS Europe (Paris, France) : hébergement principal de la plateforme
• Serveurs Google (Firebase) : notifications et analytiques

Ces transferts sont encadrés par des garanties appropriées (clauses contractuelles types, certification Privacy Shield ou équivalent) pour assurer un niveau de protection adéquat de vos données.""",
            ),

            const _Section(
              number: "10",
              title: "Données des mineurs",
              content:
                  """La plateforme Mobili n'est pas destinée aux personnes de moins de 18 ans. Nous ne collectons pas sciemment de données personnelles relatives à des mineurs.

Si vous êtes parent ou tuteur légal et que vous pensez que votre enfant mineur nous a fourni des données personnelles, contactez-nous immédiatement à privacy@my-mobili.com afin que nous puissions procéder à la suppression de ces données.""",
            ),

            const _Section(
              number: "11",
              title: "Modifications de la politique",
              content:
                  """Mobili se réserve le droit de modifier la présente politique de confidentialité à tout moment pour refléter les évolutions légales, réglementaires ou opérationnelles.

En cas de modification substantielle, vous serez informé(e) via :
• Une notification dans l'application
• Un email si votre adresse email est renseignée

La date de dernière mise à jour sera toujours indiquée en haut de ce document. La poursuite de l'utilisation de la plateforme après modification vaut acceptation de la nouvelle politique.""",
            ),

            const _Section(
              number: "12",
              title: "Contact & Délégué à la Protection des Données",
              content:
                  """Pour toute question, réclamation ou exercice de vos droits relatifs à la protection de vos données personnelles, vous pouvez contacter :

Responsable Protection des Données — Mobili SAS
Email : privacy@my-mobili.com
Support in-app : via l'onglet Support de l'application Mobili
Site web : www.my-mobili.com/confidentialite

Nous nous engageons à traiter votre demande avec sérieux et dans les meilleurs délais.""",
            ),

            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Vos données sont protégées et ne sont jamais vendues à des tiers. Mobili s'engage à respecter votre vie privée et à traiter vos données avec la plus grande transparence.",
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          height: 1.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
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
