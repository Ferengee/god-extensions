pwd = File.dirname(__FILE__)
$LOAD_PATH.unshift pwd + '/extentions'

load "driver_clear_events_patch.rb"
load "collectd_connection_poll.rb"
load "monitor_filechange.rb"
load "health.rb"
load "dependencies.rb"
load "external_events.rb"

load "http_response_code.rb"
load "notification_configuration.god.rb"
##load "overview.rb"
load "services.rb"
##load "supergod.rb"


God.load "#{pwd}/services/*.god"
