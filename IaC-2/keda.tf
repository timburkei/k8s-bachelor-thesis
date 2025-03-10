resource "kubernetes_namespace" "keda" {
  metadata {
    name = "keda"
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = kubernetes_namespace.keda.metadata[0].name
  # depends_on = [kubernetes_namespace.keda]
}

resource "null_resource" "wait_for_keda_crds" {
  depends_on = [helm_release.keda]

  provisioner "local-exec" {
    command     = <<EOT
      echo "Warte auf KEDA CRDs..."
      # Standard-Timeout: 120 Sekunden (2 Minuten)
      timeout=120
      counter=0
      
      until kubectl get crd scaledobjects.keda.sh &>/dev/null && kubectl get crd triggerauthentications.keda.sh &>/dev/null; do
        sleep 5
        counter=$((counter + 5))
        echo "Warte seit $counter Sekunden auf KEDA CRDs..."
        
        if [ $counter -ge $timeout ]; then
          echo "Timeout beim Warten auf KEDA CRDs!"
          exit 1
        fi
      done
      echo "KEDA CRDs sind verfügbar!"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}