resource "aws_iam_policy" "fireflyEventDrivenRulesPermission-665" {
  name   = "fireflyEventDrivenRulesPermission"
  policy = jsonencode({
  "Statement": [
    {
      "Action": [
        "events:*"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:events:*:717087881627:rule/firefly-events-*"
    }
  ],
  "Version": "2012-10-17"
  })
}

