# Prereqs

- Terraform
- SSH
- NodeJS
- Terraform, SSH and NodeJS

# Steps

1. run `terraform apply`
2. run `terraform output output`
3. open up an additional terminal
  1. run the "ssh" part of the previous step there
4. run the "env" part of the previous step here to export the environment variables
5. `cd nodejs`
6. `npm ci`
7. `npx node ./index.js`
