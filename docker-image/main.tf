// Create IAM role to manage elasticbeanstalk
resource "aws_iam_role_policy_attachment" "default" {
	// TODO: Restrict this policy
	policy_arn  = "arn:aws:iam::aws:policy/AdministratorAccess"
	role = aws_iam_role.default.name
}
resource "aws_iam_role" "default" {
	assume_role_policy = <<EOF
{
	"Statement": [
		{
			"Action": "sts:AssumeRole",
			"Effect": "Allow",
			"Principal": {
				"Service": "ec2.amazonaws.com"
			},
			"Sid": ""
		}
	],
	"Version": "2012-10-17"
}
EOF
}
resource "aws_iam_instance_profile" "default" {
	role = aws_iam_role.default.name
}

// Create environment
resource "random_id" "default" {
	byte_length = 40
}
resource "aws_elastic_beanstalk_application" "default" {
	name = random_id.default.b64_url
}

// Create release
resource "aws_s3_bucket" "default" {
}
resource "aws_s3_bucket_object" "default" {
	bucket = aws_s3_bucket.default.id
	key = "Dockerrun.aws.json"
	content = jsonencode({
		"AWSEBDockerrunVersion" = "1"
		"Image" = {
			"Name" = var.image
		}
		"Ports" = [
			{ "ContainerPort" = "8080" }
		]
	})
	content_type = "application/json"
}
resource "aws_elastic_beanstalk_application_version" "default" {
	application = aws_elastic_beanstalk_application.default.name
	bucket = aws_s3_bucket.default.id
	key = "Dockerrun.aws.json"
	name = replace("${var.image}", "/", "\\")
}

// Create Application
resource "aws_elastic_beanstalk_environment" "default" {
	application = aws_elastic_beanstalk_application.default.name
	name = var.name
	solution_stack_name = "64bit Amazon Linux 2 v3.0.3 running Docker"
	tier = var.type == "website" ? "WebServer" : "Worker"
	version_label = aws_elastic_beanstalk_application_version.default.id

	setting {
		name = "IamInstanceProfile"
		namespace = "aws:autoscaling:launchconfiguration"
		value = aws_iam_instance_profile.default.name
	}
	setting {
		name = "InstanceTypes"
		namespace = "aws:ec2:instances"
		value = "t3.micro"
	}
	setting {
		name = "MaxSize"
		namespace = "aws:autoscaling:asg"
		value = var.max
	}
	setting {
		name = "MinSize"
		namespace = "aws:autoscaling:asg"
		value = var.min
	}
	setting {
		name = "RollingUpdateType"
		namespace = "aws:autoscaling:updatepolicy:rollingupdate"
		value = "Immutable"
	}

	// Environmental settings
	dynamic "setting" {
		for_each = var.environment
		content {
			name = setting.value["key"]
			namespace = "aws:elasticbeanstalk:application:environment"
			value = setting.value["value"]
		}
	}
}
