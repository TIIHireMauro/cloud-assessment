# IOT Core thing, policy, certificate and attachment
# Documentation: 
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iot_thing
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iot_policy
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iot_certificate
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iot_thing_principal_attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iot_policy_attachment

# IOT Core thing
resource "aws_iot_thing" "sensor" {
  name = "sensor-001"
}

# IOT Core policy
resource "aws_iot_policy" "sensor_policy" {
  name = "sensor-001-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect",
          "iot:Publish",
          "iot:Subscribe",
          "iot:Receive"
        ]
        Resource = "*"
      }
    ]
  })
}

# IOT Core certificate
resource "aws_iot_certificate" "sensor_cert" {
  active = true
}

# IOT Core thing principal attachment
resource "aws_iot_thing_principal_attachment" "sensor_attach" {
  thing     = aws_iot_thing.sensor.name
  principal = aws_iot_certificate.sensor_cert.arn
}

# IOT Core policy attachment
resource "aws_iot_policy_attachment" "sensor_policy_attach" {
  policy = aws_iot_policy.sensor_policy.name
  target = aws_iot_certificate.sensor_cert.arn
}