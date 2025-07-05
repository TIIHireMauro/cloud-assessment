# This file is used to install the external-secrets chart so it can be used to get the secrets from the secrets manager

# Documentation: https://artifacthub.io/packages/helm/external-secrets-operator/external-secrets


resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"
  create_namespace = true
  version    = "0.10.1"
}
