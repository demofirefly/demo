resource "aws_iam_policy" "event_bus_invoke_remote_event_bus-5d6" {
  name   = "event_bus_invoke_remote_event_bus"
  policy = jsonencode({
  "Statement": [
    {
      "Action": "events:PutEvents",
      "Effect": "Allow",
      "Resource": "arn:aws:events:eu-west-1:824784664836:event-bus/stag-stablefly-event-bus",
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
  })
}

