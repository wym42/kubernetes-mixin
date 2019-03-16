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
              sum(irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])) +
              sum(irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'node:node_net_utilisation:sum_irate',
            expr: |||
              sum by (node) (
                (irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m]) +
                irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m]))
              * on (namespace, %(podLabel)s) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_net_bytes_transmitted:sum_irate',
            expr: |||
              sum by (node) (
                irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
              * on (namespace, pod) group_left(node)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_net_bytes_received:sum_irate',
            expr: |||
              sum by (node) (
                irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
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
      {
        name: 'etcd.rules',
        rules: [
          {
            record: 'etcd:up:sum',
            expr: |||
              sum(up{%(etcdSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_server_leader_changes_seen:sum_changes',
            expr: |||
              sum(changes(etcd_server_leader_changes_seen_total{%(etcdSelector)s}[1h]))
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_server_proposals_failed:sum_irate',
            expr: |||
              sum(irate(etcd_server_proposals_failed_total{%(etcdSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_server_proposals_applied:sum_irate',
            expr: |||
              sum(irate(etcd_server_proposals_applied_total{%(etcdSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_server_proposals_committed:sum_irate',
            expr: |||
              sum(irate(etcd_server_proposals_committed_total{%(etcdSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_server_proposals_pending:sum',
            expr: |||
              sum(etcd_server_proposals_pending{%(etcdSelector)s})
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_debugging_mvcc_db_total_size:sum',
            expr: |||
              sum(label_replace(etcd_debugging_mvcc_db_total_size_in_bytes{%(etcdSelector)s},"node", "$1", "instance", "(.*):.*")) by (node)
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_mvcc_db_total_size:sum',
            expr: |||
              sum(label_replace(etcd_mvcc_db_total_size_in_bytes{%(etcdSelector)s},"node", "$1", "instance", "(.*):.*")) by (node)
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_network_client_grpc_received_bytes:sum_irate',
            expr: |||
              sum(irate(etcd_network_client_grpc_received_bytes_total{%(etcdSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_network_client_grpc_sent_bytes:sum_irate',
            expr: |||
              sum(irate(etcd_network_client_grpc_sent_bytes_total{%(etcdSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:grpc_server_started:sum_irate',
            expr: |||
              sum(irate(grpc_server_started_total{%(etcdSelector)s,grpc_type="unary"}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:grpc_server_handled:sum_irate',
            expr: |||
              sum(irate(grpc_server_handled_total{%(etcdSelector)s,grpc_type="unary",grpc_code!="OK"}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:grpc_server_msg_received:sum_irate',
            expr: |||
              sum(irate(grpc_server_msg_received_total{%(etcdSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:grpc_server_msg_sent:sum_irate',
            expr: |||
              sum(irate(grpc_server_msg_sent_total{%(etcdSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_disk_wal_fsync_duration:avg',
            expr: |||
              sum(label_replace(sum(irate(etcd_disk_wal_fsync_duration_seconds_sum{%(etcdSelector)s}[5m])) by (instance) / sum(irate(etcd_disk_wal_fsync_duration_seconds_count{%(etcdSelector)s}[5m])) by (instance), "node", "$1", "instance", "(.*):.*")) by (node)
            ||| % $._config,
          },
          {
            record: 'etcd:etcd_disk_backend_commit_duration:avg',
            expr: |||
              sum(label_replace(sum(irate(etcd_disk_backend_commit_duration_seconds_sum{%(etcdSelector)s}[5m])) by (instance) / sum(irate(etcd_disk_backend_commit_duration_seconds_count{%(etcdSelector)s}[5m])) by (instance), "node", "$1", "instance", "(.*):.*")) by (node)
            ||| % $._config,
          },
        ],
      },
      {
        name: 'etcd_histogram.rules',
        rules: [
          {
            record: 'etcd:%s:histogram_quantile' % metric,
            expr: |||
              histogram_quantile(%(quantile)s, sum(label_replace(sum(irate(%(metric)s_seconds_bucket{%(etcdSelector)s}[5m])) by (instance, le), "node", "$1", "instance", "(.*):.*")) by (node, le))
            ||| % ({ quantile: quantile, metric: metric } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for metric in ['etcd_disk_wal_fsync_duration', 'etcd_disk_backend_commit_duration']      
          for quantile in ['0.99', '0.9', '0.5']
        ],
      },
      {
        name: 'apiserver.rules',
        rules: [
          {
            record: 'apiserver:up:sum',
            expr: |||
              sum(up{%(kubeApiserverSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_count:sum_irate',
            expr: |||
              sum(irate(apiserver_request_count{%(kubeApiserverSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_count:sum_verb_irate',
            expr: |||
              sum(irate(apiserver_request_count{%(kubeApiserverSelector)s}[5m])) by (verb)
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_latencies:avg',
            expr: |||
              sum(irate(apiserver_request_latencies_sum{%(kubeApiserverSelector)s, verb!~"WATCH|CONNECT"}[5m])) / sum(irate(apiserver_request_latencies_count{%(kubeApiserverSelector)s, verb!~"WATCH|CONNECT"}[5m]))/ 1e+06
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_latencies:avg_by_verb',
            expr: |||
              sum(irate(apiserver_request_latencies_sum{%(kubeApiserverSelector)s, verb!~"WATCH|CONNECT"}[5m])) by (verb) / sum(irate(apiserver_request_latencies_count{%(kubeApiserverSelector)s, verb!~"WATCH|CONNECT"}[5m])) by (verb) / 1e+06
            ||| % $._config,
          },
        ],
      },
      {
        name: 'scheduler.rules',
        rules: [
          {
            record: 'scheduler:up:sum',
            expr: |||
              sum(up{%(kubeSchedulerSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'scheduler:scheduler_schedule_attempts:sum',
            expr: |||
              sum(scheduler_schedule_attempts_total{%(kubeSchedulerSelector)s}) by (result)
            ||| % $._config,
          },
          {
            record: 'scheduler:scheduler_schedule_attempts:sum_rate',
            expr: |||
              sum(rate(scheduler_schedule_attempts_total{%(kubeSchedulerSelector)s}[5m])) by (result)
            ||| % $._config,
          },
          {
            record: 'scheduler:scheduler_e2e_scheduling_latency:avg',
            expr: |||
              (sum(rate(scheduler_e2e_scheduling_latency_microseconds_sum{%(kubeSchedulerSelector)s}[1h]))  / sum(rate(scheduler_e2e_scheduling_latency_microseconds_count{%(kubeSchedulerSelector)s}[1h]))) /  1e+06
            ||| % $._config,
          },
        ],
      },
      {
        name: 'scheduler_histogram.rules',
        rules: [
          {
            record: 'scheduler:%s:histogram_quantile' % metric,
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(%(metric)s_microseconds_bucket{%(kubeSchedulerSelector)s}[1h])) by (le) ) / 1e+06
            ||| % ({ quantile: quantile, metric: metric } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for quantile in ['0.99', '0.9', '0.5']
          for metric in ['scheduler_e2e_scheduling_latency']
        ],
      },
      {
        name: 'controller_manager.rules',
        rules: [
          {
            record: 'controller_manager:up:sum',
            expr: |||
              sum(up{%(kubeControllerManagerSelector)s} == 1)
            ||| % $._config,
          },
        ],
      },
      {
        name: 'coredns.rules',
        rules: [
          {
            record: 'coredns:up:sum',
            expr: |||
              sum(up{%(kubeCoreDNSSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_cache_hits_total:sum_irate',
            expr: |||
              sum(irate(coredns_cache_hits_total[5m]))
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_cache_misses:sum_irate',
            expr: |||
              sum(irate(coredns_cache_misses[5m]))
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_dns_request_count:sum_irate',
            expr: |||
              sum(irate(coredns_dns_request_count_total{%(kubeCoreDNSSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_dns_request_type_count:sum_irate',
            expr: |||
              sum(irate(coredns_dns_request_type_count_total[5m])) by (type)
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_dns_response_rcode_count:sum_irate',
            expr: |||
              sum(irate(coredns_dns_response_rcode_count_total[5m])) by (rcode)
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_panic_count:sum_irate',
            expr: |||
              sum(irate(coredns_panic_count_total[5m]))
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_proxy_request_count:sum_irate',
            expr: |||
              sum(irate(coredns_proxy_request_count_total{%(kubeCoreDNSSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_dns_request_duration:avg',
            expr: |||
              sum(irate(coredns_dns_request_duration_seconds_sum{%(kubeCoreDNSSelector)s}[5m])) / sum(irate(coredns_dns_request_duration_seconds_count{%(kubeCoreDNSSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'coredns:coredns_proxy_request_duration:avg',
            expr: |||
              sum(irate(coredns_proxy_request_duration_seconds_sum{%(kubeCoreDNSSelector)s}[5m])) / sum(irate(coredns_proxy_request_duration_seconds_count{%(kubeCoreDNSSelector)s}[5m]))
            ||| % $._config,
          },
        ],
      },
      {
        name: 'coredns_histogram.rules',
        rules: [
          {
            record: 'coredns:%s:histogram_quantile' % metric,
            expr: |||
              histogram_quantile(%(quantile)s, sum(irate(%(metric)s_seconds_bucket{%(kubeCoreDNSSelector)s}[5m])) by (le))
            ||| % ({ quantile: quantile, metric: metric } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for metric in ['coredns_dns_request_duration', 'coredns_proxy_request_duration']
          for quantile in ['0.99', '0.9', '0.5']
        ],
      },
      {
        name: 'prometheus.rules',
        rules: [
          {
            record: 'prometheus:up:sum',
            expr: |||
              sum(up{%(prometheusSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'prometheus:prometheus_tsdb_head_samples_appended:sum_rate',
            expr: |||
              sum(rate(prometheus_tsdb_head_samples_appended_total{%(prometheusSelector)s} [5m])) by (job)
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
