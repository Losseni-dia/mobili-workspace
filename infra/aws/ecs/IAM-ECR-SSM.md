# Rôle d’exécution ECS — ECR, logs CloudWatch, lecture SSM

Le **`executionRoleArn`** pointé par [`task-definition.json`](task-definition.json) (ex. `mobiliEcsTaskExecutionRole`) doit agréger :

1. **Politique managée** : `service-role/AmazonECSTaskExecutionRolePolicy`  
   (ECR, logs, pas SSM seul : compléter ci-dessous.)

2. **Politique en ligne (SSM Parameter Store)** — lecture des paramètres recette :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SsmReadMobiliStaging",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter",
        "ssm:GetParameterHistory"
      ],
      "Resource": "arn:aws:ssm:eu-west-3:420943511896:parameter/mobili/staging/*"
    }
  ]
}
```

3. Si un paramètre est **SecureString** avec clé **KMS** gérée par toi, ajoute sur ce rôle `kms:Decrypt` sur l’ARN de la clé utilisée.

Enregistrement de la task (CLI) :  
`aws ecs register-task-definition --cli-input-json file://task-definition.json --region eu-west-3`

Crée au préalable les paramètres SSM, ex. :  
`/mobili/staging/DB_URL`, … (les ARNs des `valueFrom` du JSON correspondent à ces chemins).
