data "terraform_remote_state" "infrastructure" {
  backend = "local" # oder dein verwendeter Backend-Typ (z. B. azurerm)
  config = {
    path = "../IaC-1/terraform.tfstate" # Pfad zu deinem IaC‑1 State
  }
}