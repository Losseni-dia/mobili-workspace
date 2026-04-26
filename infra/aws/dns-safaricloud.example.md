# Exemple d’enregistrements DNS (zone `mobili.ci`)

Remplis les cibles **réelles** une fois **CloudFront** et **l’ALB** (ou équivalent) créés dans AWS.

| # | Type | Host / Nom | Cible (copier depuis la console AWS) |
|---|------|------------|--------------------------------------|
| 1 | CNAME | `int` | `d____________.cloudfront.net` |
| 2 | CNAME | `www.int` | *(même que ligne 1 si www utilisé)* |
| 3 | CNAME | `api.int` | `xxx-xxxxxxxx.eu-west-3.elb.amazonaws.com` |
| 4 | CNAME | *(selon ACM)* | *(CNAME de validation des certificats — temporaire)* |

**Notes**

- Ne pas mettre d’`https://` dans le champ cible d’un CNAME.
- La validation **ACM** ajoute des CNAME de type `_xxxx.int.mobili.ci` : à créer tels quels quand le certificat est en *Pending validation*.
