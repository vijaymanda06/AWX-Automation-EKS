# --- Random Passwords ---

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "random_password" "awx_admin_password" {
  length  = 20
  special = false
}

# --- Secrets Manager ---

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/rds/awx-db-credentials"
  description             = "AWX RDS PostgreSQL credentials"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.awx.address
    port     = 5432
    dbname   = var.db_name
    engine   = "postgres"
  })
}

resource "aws_secretsmanager_secret" "awx_admin" {
  name                    = "${var.project_name}/awx/admin-credentials"
  description             = "AWX admin user credentials"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-awx-admin"
  }
}

resource "aws_secretsmanager_secret_version" "awx_admin" {
  secret_id = aws_secretsmanager_secret.awx_admin.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.awx_admin_password.result
  })
}
