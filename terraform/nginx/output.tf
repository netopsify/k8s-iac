data "kubernetes_service" "nginx" {
  metadata {
    name = "nginx-service"
  }
  depends_on = [kubernetes_service.nginx]
}

output "service" {
  value = "http://${data.kubernetes_service.nginx.load_balancer_ingress[0].ip}:${data.kubernetes_service.nginx.spec[0].port[0].port}"
}

output "node_port" {
  value = "${data.kubernetes_service.nginx.spec[0].port[0].port}"
}

output "service_name" {
  value = "${data.kubernetes_service.nginx.metadata[0].name}"
}