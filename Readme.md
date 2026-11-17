# Terraform AWS Web Application Infrastructure

This project sets up a complete web application infrastructure on AWS with:
- Two EC2 instances serving a simple web application
- Application Load Balancer for traffic distribution
- PostgreSQL RDS database
- S3 bucket for application data
- Remote state management with S3 backend and DynamoDB locking

## Prerequisites

- Terraform must be installed
- AWS CLI must be installed
- Generate an AWS IAM user and assign proper permissions (EC2, RDS, S3, DynamoDB, VPC, ELB)
- Generate API keys and configure with `aws configure`

## Project Structure

```
.
├── backend-setup/       # Sets up S3 bucket and DynamoDB for remote state
│   └── main.tf
└── infrastructure/      # Main web application infrastructure
    └── main.tf
```

## Infrastructure Components

### 1. Remote State Backend (S3 + DynamoDB)

**Location**: `backend-setup/main.tf`

Creates:
- **S3 Bucket**: `terraform-state-bucket-97da5e70`
  - Stores Terraform state files
  - Versioning enabled for state history
  - AES256 encryption for security
  
- **DynamoDB Table**: `terraform-state-locking`
  - Prevents concurrent state modifications
  - Uses `LockID` as hash key

### 2. Web Servers (EC2 Instances)

**Resources**: `aws_instance.instance_1`, `aws_instance.instance_2`

Two identical Ubuntu 20.04 LTS instances that:
- Run on `t3.micro` instance type
- Use user data script to:
  - Create an `index.html` file
  - Start a Python HTTP server on port 8080
- Each serves different content ("Hello, World 1" and "Hello, World 2")

### 3. Application Load Balancer (ALB)

**Resources**: `aws_lb.load_balancer`, `aws_lb_listener.http`, `aws_lb_target_group.instances`

The load balancer:
- Distributes incoming HTTP traffic across both EC2 instances
- Performs health checks on port 8080
- Returns 404 for unmatched routes
- Provides a single DNS endpoint for the application

**Flow**:
```
Internet → ALB (port 80) → Target Group → EC2 Instances (port 8080)
```

### 4. Security Groups

**Instance Security Group**: `aws_security_group.instances`
- Allows inbound traffic on port 8080 (web server)

**Load Balancer Security Group**: `aws_security_group.alb`
- Allows inbound HTTP traffic on port 80
- Allows all outbound traffic

### 5. S3 Bucket (Application Data)

**Resource**: `aws_s3_bucket.bucket`

Application data bucket with:
- Unique prefix: `tf-web-app-data-97da5e70-`
- Versioning enabled
- AES256 server-side encryption
- `force_destroy = true` for easy cleanup

### 6. PostgreSQL Database (RDS)

**Resource**: `aws_db_instance.db_instance`

A managed PostgreSQL database:
- **Engine**: PostgreSQL 12
- **Instance Class**: `db.t3.micro`
- **Storage**: 20 GB (standard)
- **Auto minor version upgrades**: Enabled
- **Database name**: `mydb`
- **Credentials**: 
  - Username: `foo`
  - Password: `foobarbaz` ⚠️ *Change in production!*

### 7. Networking

Uses AWS default VPC and subnets:
- **VPC**: Retrieved via `data.aws_vpc.default_vpc`
- **Subnets**: Retrieved via `data.aws_subnets.default_subnet`
- Automatically selects all default subnets in eu-central-1

## Usage

### Step 1: Set Up Backend

First, create the S3 bucket and DynamoDB table for remote state:

```bash
cd backend-setup
terraform init
terraform plan
terraform apply
```

This creates the infrastructure needed to store Terraform state remotely.

### Step 2: Deploy Infrastructure

Deploy the main web application:

```bash
cd ../infrastructure
terraform init
terraform plan
terraform apply
```

### Step 3: Access Your Application

After deployment, Terraform outputs:
- **Load Balancer DNS**: Access your web app at `http://<load_balancer_dns>`
- **Individual Instance IPs**: Direct access to instances (for debugging)
- **Database Endpoint**: Connection string for PostgreSQL
- **S3 Bucket Name**: For uploading application data

Example:
```bash
# Get the load balancer URL
terraform output load_balancer_dns
# Output: web-app-lb-1234567890.eu-central-1.elb.amazonaws.com

# Visit in browser
curl http://web-app-lb-1234567890.eu-central-1.elb.amazonaws.com
# Returns: "Hello, World 1" or "Hello, World 2" (round-robin)
```

### Step 4: Cleanup

To destroy all resources:

```bash
# Destroy application infrastructure
cd infrastructure
terraform destroy

# Destroy backend (if desired)
cd ../backend-setup
terraform destroy
```

## Important Notes

⚠️ **Security Warnings**:
- Database password is hardcoded - use AWS Secrets Manager in production
- Security groups allow traffic from `0.0.0.0/0` - restrict in production
- `skip_final_snapshot = true` on RDS - enable snapshots in production

💰 **Cost Considerations**:
- RDS instances run continuously and incur charges
- Application Load Balancers have hourly charges
- t3.micro instances are eligible for AWS Free Tier

🔧 **Unique Identifier**:
The suffix `97da5e70` ensures globally unique resource names:
```bash
# Generate new unique ID if needed
uuidgen | tr '[:upper:]' '[:lower:]' | cut -d'-' -f1
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                   Internet                       │
└────────────────────┬────────────────────────────┘
                     │
              ┌──────▼──────┐
              │     ALB     │ (Port 80)
              │ (eu-central)│
              └──────┬──────┘
                     │
        ┌────────────┴────────────┐
        │                         │
   ┌────▼─────┐             ┌────▼─────┐
   │ Instance │             │ Instance │
   │    1     │ (Port 8080) │    2     │
   │ Ubuntu   │             │ Ubuntu   │
   └──────────┘             └──────────┘
        │                         │
        └────────────┬────────────┘
                     │
              ┌──────▼──────┐
              │  S3 Bucket  │  (Application Data)
              └─────────────┘
              ┌──────▼──────┐
              │     RDS     │  (PostgreSQL)
              │  (Managed)  │
              └─────────────┘

State Management:
┌─────────────┐      ┌──────────────┐
│ S3 Backend  │◄────►│  DynamoDB    │
│   (State)   │      │   (Locks)    │
└─────────────┘      └──────────────┘
```

## Troubleshooting

**Issue**: "BucketAlreadyExists" error
- **Solution**: S3 bucket names are globally unique. Change the bucket name in both files.

**Issue**: Load balancer returns 404
- **Solution**: Wait 2-3 minutes for instances to pass health checks.

**Issue**: Can't connect to database
- **Solution**: Check security groups and ensure RDS instance is in `available` state.