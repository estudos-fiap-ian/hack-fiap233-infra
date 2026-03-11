###############################################################################
# Random password for the database
###############################################################################

resource "random_password" "db_password" {
  length  = 24
  special = false
}

###############################################################################
# Subnet Group
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.service_name}-db-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.service_name}-db-subnet"
  }
}

###############################################################################
# Parameter Group
###############################################################################

resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.service_name}-db-params"
  family = "postgres16"

  tags = {
    Name = "${var.project_name}-${var.service_name}-db-params"
  }
}

###############################################################################
# RDS Instance
###############################################################################

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.service_name}-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = var.security_group_ids

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-${var.service_name}-db"
  }
}

###############################################################################
# Secrets Manager
###############################################################################

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}/${var.service_name}/db-credentials"

  tags = {
    Name = "${var.project_name}-${var.service_name}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    engine   = "postgres"
  })
}
