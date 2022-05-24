terraform {
  backend "remote" {
    organization = "trustsoft-moneta"
    workspaces {
      prefix = "test-documentdb_"
    }
  }
}
