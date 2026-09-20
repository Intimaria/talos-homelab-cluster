# Create a namespace to hold our users (ServiceAccounts)
resource "kubernetes_namespace" "rbac_users" {
  metadata {
    name = "rbac-users"
  }
}

# --- Service Accounts ---
resource "kubernetes_service_account" "admin" {
  metadata {
    name      = "admin-user"
    namespace = kubernetes_namespace.rbac_users.metadata[0].name
  }
}

resource "kubernetes_service_account" "dev" {
  metadata {
    name      = "dev-user"
    namespace = kubernetes_namespace.rbac_users.metadata[0].name
  }
}

resource "kubernetes_service_account" "readonly" {
  metadata {
    name      = "readonly-user"
    namespace = kubernetes_namespace.rbac_users.metadata[0].name
  }
}

# --- Secrets for Tokens (Required for K8s 1.24+) ---
resource "kubernetes_secret" "admin_token" {
  metadata {
    name      = "admin-user-token"
    namespace = kubernetes_namespace.rbac_users.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.admin.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_secret" "dev_token" {
  metadata {
    name      = "dev-user-token"
    namespace = kubernetes_namespace.rbac_users.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.dev.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_secret" "readonly_token" {
  metadata {
    name      = "readonly-user-token"
    namespace = kubernetes_namespace.rbac_users.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.readonly.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# --- Roles ---

# Dev Role (Deploy apps, get namespaces, debug)
# Note: For admin and readonly, we can just use the built-in 'cluster-admin' and 'view' roles.
resource "kubernetes_cluster_role" "dev_role" {
  metadata {
    name = "dev-role"
  }

  # Allow viewing namespaces and nodes
  rule {
    api_groups = [""]
    resources  = ["namespaces", "nodes"]
    verbs      = ["get", "list", "watch"]
  }

  # Allow managing app workloads and resources
  rule {
    api_groups = ["", "apps", "batch", "extensions", "networking.k8s.io"]
    resources = [
      "deployments", "replicasets", "pods", "services", "ingresses",
      "configmaps", "jobs", "cronjobs", "statefulsets",
      "daemonsets", "persistentvolumeclaims"
    ]
    verbs = ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
  }

  # Allow read-only access to secrets cluster-wide (avoids privilege escalation warning)
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }

  # Allow debugging (exec, port-forward, logs)
  rule {
    api_groups = [""]
    resources  = ["pods/portforward", "pods/exec", "pods/log"]
    verbs      = ["create", "get", "list"]
  }
}

# --- Bindings ---

# Admin Binding (uses built-in cluster-admin)
resource "kubernetes_cluster_role_binding" "admin_binding" {
  metadata {
    name = "admin-user-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.admin.metadata[0].name
    namespace = kubernetes_service_account.admin.metadata[0].namespace
  }
}

# Dev Binding
resource "kubernetes_cluster_role_binding" "dev_binding" {
  metadata {
    name = "dev-user-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.dev_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dev.metadata[0].name
    namespace = kubernetes_service_account.dev.metadata[0].namespace
  }
}

# ReadOnly Binding (uses built-in view)
resource "kubernetes_cluster_role_binding" "readonly_binding" {
  metadata {
    name = "readonly-user-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.readonly.metadata[0].name
    namespace = kubernetes_service_account.readonly.metadata[0].namespace
  }
}

# Outputs to easily retrieve the tokens for each user
output "admin_token" {
  description = "Token for the admin ServiceAccount"
  value       = kubernetes_secret.admin_token.data["token"]
  sensitive   = true
}

output "dev_token" {
  description = "Token for the dev ServiceAccount"
  value       = kubernetes_secret.dev_token.data["token"]
  sensitive   = true
}

output "readonly_token" {
  description = "Token for the readonly ServiceAccount"
  value       = kubernetes_secret.readonly_token.data["token"]
  sensitive   = true
}

# --- Automated Kubeconfig Generation ---
# This will automatically create ready-to-use kubeconfig files in your talos-tofu directory

resource "local_sensitive_file" "dev_kubeconfig" {
  filename = "${path.module}/kubeconfig-dev"
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      cluster = {
        "certificate-authority-data" = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.ca_certificate
        server                       = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.host
      }
      name = var.cluster_name
    }]
    contexts = [{
      context = {
        cluster = var.cluster_name
        user    = "dev-user"
      }
      name = "dev-context"
    }]
    "current-context" = "dev-context"
    users = [{
      name = "dev-user"
      user = {
        token = kubernetes_secret.dev_token.data["token"]
      }
    }]
  })
}

resource "local_sensitive_file" "readonly_kubeconfig" {
  filename = "${path.module}/kubeconfig-readonly"
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      cluster = {
        "certificate-authority-data" = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.ca_certificate
        server                       = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.host
      }
      name = var.cluster_name
    }]
    contexts = [{
      context = {
        cluster = var.cluster_name
        user    = "readonly-user"
      }
      name = "readonly-context"
    }]
    "current-context" = "readonly-context"
    users = [{
      name = "readonly-user"
      user = {
        token = kubernetes_secret.readonly_token.data["token"]
      }
    }]
  })
}
