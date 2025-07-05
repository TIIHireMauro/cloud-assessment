# Lambda - Documentation: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
# Here I'm not using modules because it's temporary and will be replaced by real IoT devices

# This is a simple example of a Lambda function that simulates an IoT device
# It publishes data to an IoT topic
# It's not used in the project, but it's a good example of how to use Lambda and also will be used for demo purposes

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_iot_publish" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AWSIoTFullAccess"
}

resource "aws_lambda_function" "iot_simulator" {
  function_name = "simulator"
  description   = "Simulates an IoT device and publishes data to an IoT topic"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "simulator.zip"
  environment {
    variables = {
      MQTT_BROKER_URL = "tii-iot-core-endpoint.amazonaws.com"
      MQTT_TOPIC      = "iot/data"
      DEVICE_ID       = "sensor-lambda"
      PUBLISH_INTERVAL_MS = 2000
    }
  }
}
