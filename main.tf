resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/24"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "igw" {
  route_table_id = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_security_group" "grp" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ssh" {
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBI2Al+h997lxzXenePAc4EK9pJhouZPPa96iu01SnrEquef+5Jj7L/VMbyID0YneOC/iGtpS4Iy3EfWFK1nK5FAo/O8E2sTmJ4/q/R3ykaEA4GqCVefAdQrYihwedTe0fs99uERdUQZd63IhULfm4d4/LNf/MIynGd+xPNXA+XYR7w0hAAvu24f+f3CVps2cLgg3BZbVaz0qhdVaQcRDC2iwgzcc82O2RsaKfbVqCZMOQqisba4kMXjrKqb5HVg1LGdPVsfqdHdcTVQIW6/1r1PjPW5fqk8nGelG6XB17E97rZg7tQ6SuWeqM2SDFQXW6LjMZ4o+c61VtU3xMwSeCWnz/GQnHGh8B/LtAFiGPDz532nwdan/Qz4FdAOwP3ruwRJAy9cQJjYtnm3E1/n+Gjlj0bE4vpgW3KwsN6Dq8GkgepgLpmlVOTTHxBlJNphHA3rpKR1mYKmV07JK1f2tDm0aAgg/SENVazDzEY4kr4DeB/hmZ+NJNQKiCh6r16co2MRwpt5cxHxyAtZ8cLQUflAONbLlH2etz/dQmmgbW9N/uR6G0CyehBT29kv17ZD58pjFglqLhkckBLrXO6w2ELqFD25ylppAb/Yq6SERnJOa+cJ4sVqgZ4q/xubHQlbYYfMLdX/ZVa0ojUTyUR/zYyLPT/UpCH/dohFfZMZy+3Q=="
}

resource "aws_instance" "ssh" {
  instance_type = "t4g.micro"
  ami = "ami-0641bed8c0ce71686"

  key_name = aws_key_pair.ssh.key_name

  subnet_id = aws_subnet.main["az1"].id
  vpc_security_group_ids = [aws_security_group.grp.id]
}

resource "aws_eip" "ssh" {
  instance = aws_instance.ssh.id
}

resource "aws_subnet" "main" {
  for_each = {
    az1 = {
      aws_availability_zone = "eu-central-1a"
      cidr = "10.0.0.0/28"
    }
    az2 = {
      aws_availability_zone = "eu-central-1b"
      cidr = "10.0.0.16/28"
    }
    az3 = {
      aws_availability_zone = "eu-central-1c"
      cidr = "10.0.0.32/28"
    }
  }

  vpc_id = aws_vpc.main.id
  cidr_block = each.value.cidr
  availability_zone = each.value.aws_availability_zone
}

resource "aws_docdb_subnet_group" "grp" {
  name = "grp"
  subnet_ids = [for subnet in aws_subnet.main: subnet.id]
}

resource "random_string" "password" {
  length = 16
  special = false
  min_lower = 1
}

resource "aws_docdb_cluster" "cls" {
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  apply_immediately = true
  cluster_identifier = "test"
  engine = "docdb"
  master_username = "root"
  master_password = random_string.password.result
  skip_final_snapshot = true
  db_subnet_group_name = aws_docdb_subnet_group.grp.name
  vpc_security_group_ids = [aws_security_group.grp.id]
}

resource "aws_docdb_cluster_instance" "inst" {
  for_each = {
    az1 = {
      aws_availability_zone = "eu-central-1a"
    }
    az2 = {
      aws_availability_zone = "eu-central-1b"
    }
    az3 = {
      aws_availability_zone = "eu-central-1c"
    }
  }

  apply_immediately = true
  identifier = "inst-${each.key}"
  cluster_identifier = aws_docdb_cluster.cls.cluster_identifier
  availability_zone = each.value.aws_availability_zone
  instance_class = "db.t4g.medium"
}

output "output" {
  value = {
    password = random_string.password.result
    cls = {
      endpoint = aws_docdb_cluster.cls.endpoint
    }
    ssh = {
      public_ip = aws_eip.ssh.public_ip
    }
    envs = <<-EOT
      export MONGO_USER="${aws_docdb_cluster.cls.master_username}"
      export MONGO_PASSWORD="${aws_docdb_cluster.cls.master_password}"
      export MONGO_HOST="${aws_docdb_cluster.cls.endpoint}"
      export MONGO_PORT="${aws_docdb_cluster.cls.port}"
      export MONGO_SOCKS_PORT="${aws_docdb_cluster.cls.port}"
    EOT
    ssh = <<-EOT
      ssh -D ${aws_docdb_cluster.cls.port} ubuntu@"${aws_eip.ssh.public_ip}"
    EOT
  }
  sensitive = true
}
