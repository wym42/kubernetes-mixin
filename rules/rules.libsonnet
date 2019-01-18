{
  prometheusRules+:: {
    groups+: [
      {
        name: 'k8s.rules',
        rules: [
          {
            record: 'namespace:container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum(rate(container_cpu_usage_seconds_total{%(kubeletSelector)s, image!="", container_name!=""}[5m])) by (namespace)
            ||| % $._config,
          },
          {
            record: 'namespace:container_memory_usage_bytes:sum',
            expr: |||
              sum(container_memory_usage_bytes{%(kubeletSelector)s, image!="", container_name!=""}) by (namespace)
            ||| % $._config,
          },
          {
            record: 'namespace:container_memory_usage_bytes_wo_cache:sum',
            expr: |||
              sum(container_memory_usage_bytes{%(kubeletSelector)s, image!="", container_name!=""} - container_memory_cache{%(kubeletSelector)s, image!="", container_name!=""}) by (namespace)
            ||| % $._config,
          },
        ],
      },
      {
        name: 'node.rules',
        rules: [
          {
            // This rule results in the tuples (node, namespace, instance) => 1;
            // it is used to calculate per-node metrics, given namespace & instance.
            record: 'node_namespace_pod:kube_pod_info:',
            expr: |||
              max(label_replace(kube_pod_info{%(kubeStateMetricsSelector)s}, "%(podLabel)s", "$1", "pod", "(.*)")) by (node, namespace, %(podLabel)s)
            ||| % $._config,
          },
          {
            // This rule gives the number of CPUs per node.
            record: 'node:node_num_cpu:sum',
            expr: |||
              count by (node) (sum by (node, cpu) (
                node_cpu_seconds_total{%(nodeExporterSelector)s}
              * on (namespace, %(podLabel)s) group_left(node)
                node_namespace_pod:kube_pod_info:
              ))
            ||| % $._config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: ':node_cpu_utilisation:avg1m',
            expr: |||
              avg(irate(node_cpu_seconds_total{%(nodeExporterSelector)s,mode="used"}[5m]))
            ||| % $._config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: 'node:node_cpu_utilisation:avg1m',
            expr: |||
              avg by (node) (
                irate(node_cpu_seconds_total{%(nodeExporterSelector)s,mode="used"}[5m])
              * on (namespace, %(podLabel)s) group_left(node)
                node_namespace_pod:kube_pod_info:)
            ||| % $._config,
          },
          {
            record: ':node_memory_utilisation:',
            expr: |||
              1 -
              sum(node_memory_MemFree_bytes{%(nodeExporterSelector)s} + node_memory_Cached_bytes{%(nodeExporterSelector)s} + node_memory_Buffers_bytes{%(nodeExporterSelector)s})
              /
              sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s})
            ||| % $._config,
          },
          {
            // Available memory per node
            // SINCE 2018-02-08
            record: 'node:node_memory_bytes_available:sum',
            expr: |||
              sum by (node) (
                (node_memory_MemFree_bytes{%(nodeExporterSelector)s} + node_memory_Cached_bytes{%(nodeExporterSelector)s} + node_memory_Buffers_bytes{%(nodeExporterSelector)s})
                * on (namespace, %(podLabel)s) group_left(node)
                  node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // Total memory per node
            // SINCE 2018-02-08
            record: 'node:node_memory_bytes_total:sum',
            expr: |||
              sum by (node) (
                node_memory_MemTotal_bytes{%(nodeExporterSelector)s}
                * on (namespace, %(podLabel)s) group_left(node)
                  node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // DEPENDS 2018-02-08
            // REPLACE node:node_memory_utilisation:
            record: 'node:node_memory_utilisation:',
            expr: |||
              1 - (node:node_memory_bytes_available:sum / node:node_memory_bytes_total:sum)
            ||| % $._config,
          },
          {
            record: 'node:data_volume_iops_reads:sum',
            expr: |||
              sum by (node) (
                irate(node_disk_reads_completed_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:data_volume_iops_writes:sum',
            expr: |||
              sum by (node) (
                irate(node_disk_writes_completed_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:data_volume_throughput_bytes_read:sum',
            expr: |||
              sum by (node) (
                irate(node_disk_read_bytes_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:data_volume_throughput_bytes_written:sum',
            expr: |||
              sum by (node) (
                irate(node_disk_written_bytes_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: ':node_net_utilisation:sum_irate',
            expr: |||
              sum(irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[1m])) +
              sum(irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[1m]))
            ||| % $._config,
          },
          {
            record: 'node:node_net_utilisation:sum_irate',
            expr: |||
              sum by (node) (
                (irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[1m]) +
                irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[1m]))
              * on (namespace, %(podLabel)s) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_net_bytes_transmitted:sum_irate',
            expr: |||
              sum by (node) (
                irate(node_network_transmit_bytes{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
              * on (namespace, pod) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_net_bytes_received:sum_irate',
            expr: |||
              sum by (node) (
                irate(node_network_receive_bytes{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
              * on (namespace, pod) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_inodes_total:',
            expr: |||
              max(
                max(
                  kube_pod_info{%(kubeStateMetricsSelector)s, host_ip!=""}
                ) by (node, host_ip)
                * on (host_ip) group_right (node)
                label_replace(
                  (max(node_filesystem_files{%(nodeExporterSelector)s, %(hostMountpointSelector)s}) by (instance)), "host_ip", "$1", "instance", "(.*):.*"
                )
              ) by (node)
            ||| % $._config,
          },
          {
            record: 'node:node_inodes_free:',
            expr: |||
              max(
                max(
                  kube_pod_info{%(kubeStateMetricsSelector)s, host_ip!=""}
                ) by (node, host_ip)
                * on (host_ip) group_right (node)
                label_replace(
                  (max(node_filesystem_files_free{%(nodeExporterSelector)s, %(hostMountpointSelector)s}) by (instance)), "host_ip", "$1", "instance", "(.*):.*"
                )
              ) by (node)
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
