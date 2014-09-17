##SIP:WISE NGCP/SPCE + ELK
The following snippets will allow you to ship your sip:wise CE/PRO logs to a remote ELK stack for fun and profit. 


##Logstash configuration
The proposed filter parses the standard syslog format as well as the CALL-ID (ID=) field for easy correlation of logs with SIP traces.

#### Logstash Config: save as /etc/logstash/conf.d/ngcp.conf

```
input {
  udp {
    port => 5514
    type => "ngcp"
  }
}

filter {
  if [type] == "ngcp" {
    grok {
      match => { "message" => "^(?:<%{POSINT:syslog_pri}>)?%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:$
      add_field => [ "received_at", "%{@timestamp}" ]
      add_field => [ "received_from", "%{host}" ]
    }
    grok {
        match=> { "syslog_message" => "ID=%{GREEDYDATA:call_id}" }
    }
    syslog_pri { }
    date {
      match => [ "syslog_timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    }
  }
}

output {
  if [type] == "ngcp" {
    elasticsearch {
    host => "127.0.0.1"
    }
  }
}

```


### NGCP Settings to enable RSyslog
####Edit your /etc/ngcp-config/config.yml
```
...

syslog:
  external_address: {your.logstash.ip.here}
  external_log: 1
  external_loglevel: info
  external_port: 5514
  external_proto: udp

...
```
####Apply the new rsyslog settings:
`ngcpcfg apply`


####Verify logs being shipped with ngrep:
```
ngrep -W byline port 5514
```
