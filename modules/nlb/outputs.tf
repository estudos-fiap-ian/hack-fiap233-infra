output "nlb_arn" {
  description = "ARN of the internal NLB"
  value       = aws_lb.internal.arn
}

output "nlb_dns_name" {
  description = "DNS name of the internal NLB"
  value       = aws_lb.internal.dns_name
}

output "listener_users_arn" {
  description = "ARN of the NLB listener for the users service"
  value       = aws_lb_listener.users.arn
}

output "listener_videos_arn" {
  description = "ARN of the NLB listener for the videos service"
  value       = aws_lb_listener.videos.arn
}

output "target_group_users_arn" {
  description = "ARN of the target group for the users service"
  value       = aws_lb_target_group.users.arn
}

output "target_group_videos_arn" {
  description = "ARN of the target group for the videos service"
  value       = aws_lb_target_group.videos.arn
}
