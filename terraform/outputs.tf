

output "private_key_pem" {
  value     = tls_private_key.jenkins_key.private_key_pem
  sensitive = true
}
